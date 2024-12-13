from pathlib import Path
import asyncio
import aiohttp
import aiofiles
from bs4 import BeautifulSoup
import pandas as pd
import boto3
import os
import logging
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
import shutil
import json
from urllib.parse import urljoin
from typing import Dict, List, Tuple
import random
import time

class JewelryDatasetManager:
    def __init__(self, config: Dict = None):
        self.config = {
            'input_dir': 'raw_data',
            'output_dir': 'processed_datasets',
            'aws_bucket': 'jewelry-images-input-bucket',
            'min_image_size': 512,
            'max_images_per_category': 1000,
            'user_agents': [
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            ]
        }
        if config:
            self.config.update(config)
            
        self.s3 = boto3.client('s3')
        self.setup_logging()
        
    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('dataset_creation.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('JewelryDataset')

    async def process_local_folders(self, base_dir: str):
        """Process local folder structure containing jewelry images"""
        base_path = Path(base_dir)
        self.logger.info(f"Processing folders in {base_dir}")
        
        # Create output structure
        output_base = Path(self.config['output_dir'])
        output_base.mkdir(exist_ok=True)
        
        # Process each category folder
        for category_dir in base_path.iterdir():
            if category_dir.is_dir():
                category_name = category_dir.name
                self.logger.info(f"Processing category: {category_name}")
                
                # Create category output dir
                category_output = output_base / category_name
                category_output.mkdir(exist_ok=True)
                
                # Process images in parallel
                with ThreadPoolExecutor() as executor:
                    image_paths = list(category_dir.glob('**/*.jpg')) + \
                                list(category_dir.glob('**/*.png'))
                    
                    futures = [
                        executor.submit(
                            self.process_single_image,
                            img_path,
                            category_output
                        )
                        for img_path in image_paths
                    ]
                    
                    # Collect results
                    metadata = []
                    for future in futures:
                        try:
                            result = future.result()
                            if result:
                                metadata.append(result)
                        except Exception as e:
                            self.logger.error(f"Error processing image: {str(e)}")
                
                # Save category metadata
                self.save_metadata(category_name, metadata)

    def process_single_image(self, image_path: Path, output_dir: Path) -> Dict:
        """Process a single image and return its metadata"""
        try:
            # Open and validate image
            with Image.open(image_path) as img:
                # Check size
                if min(img.size) < self.config['min_image_size']:
                    return None
                
                # Convert to RGB if necessary
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Generate unique filename
                output_name = f"{image_path.stem}_{random.randint(1000, 9999)}.jpg"
                output_path = output_dir / output_name
                
                # Save processed image
                img.save(output_path, 'JPEG', quality=95)
                
                # Upload to S3
                self.upload_to_s3(output_path, image_path.parent.name, output_name)
                
                return {
                    'original_path': str(image_path),
                    'processed_path': str(output_path),
                    'category': image_path.parent.name,
                    'dimensions': img.size,
                    's3_key': f"{image_path.parent.name}/{output_name}"
                }
                
        except Exception as e:
            self.logger.error(f"Error processing {image_path}: {str(e)}")
            return None

    def upload_to_s3(self, file_path: Path, category: str, filename: str):
        """Upload processed image to S3"""
        try:
            s3_key = f"{category}/{filename}"
            self.s3.upload_file(
                str(file_path),
                self.config['aws_bucket'],
                s3_key
            )
        except Exception as e:
            self.logger.error(f"S3 upload error for {file_path}: {str(e)}")

    def save_metadata(self, category: str, metadata: List[Dict]):
        """Save metadata for a category"""
        output_base = Path(self.config['output_dir'])
        metadata_file = output_base / f"{category}_metadata.json"
        
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)

class JewelryWebScraper:
    def __init__(self, config: Dict = None):
        self.config = {
            'output_dir': 'scraped_data',
            'delay_range': (1, 3),
            'max_retries': 3,
            'concurrent_requests': 5,
            'target_sites': [
                {
                    'url': 'https://example-jewelry-site.com',
                    'selectors': {
                        'image': 'div.product-image img',
                        'title': 'h1.product-title',
                        'price': 'span.price'
                    }
                }
            ]
        }
        if config:
            self.config.update(config)
            
        self.setup_logging()

    def setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('scraper.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('JewelryScraper')

    async def start_scraping(self):
        """Start the scraping process"""
        async with aiohttp.ClientSession() as session:
            for site in self.config['target_sites']:
                self.logger.info(f"Scraping site: {site['url']}")
                await self.scrape_site(session, site)

    async def scrape_site(self, session: aiohttp.ClientSession, site: Dict):
        """Scrape a single site"""
        try:
            # Get product listing pages
            product_urls = await self.get_product_urls(session, site['url'])
            
            # Create semaphore for concurrent requests
            semaphore = asyncio.Semaphore(self.config['concurrent_requests'])
            
            # Scrape products concurrently
            tasks = [
                self.scrape_product(session, url, site['selectors'], semaphore)
                for url in product_urls
            ]
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Filter out errors and save results
            valid_results = [r for r in results if isinstance(r, dict)]
            self.save_scrape_results(site['url'], valid_results)
            
        except Exception as e:
            self.logger.error(f"Error scraping site {site['url']}: {str(e)}")

    async def get_product_urls(self, session: aiohttp.ClientSession, base_url: str) -> List[str]:
        """Get list of product URLs to scrape"""
        # Implement based on specific site structure
        pass

    async def scrape_product(
        self,
        session: aiohttp.ClientSession,
        url: str,
        selectors: Dict,
        semaphore: asyncio.Semaphore
    ) -> Dict:
        """Scrape a single product page"""
        async with semaphore:
            try:
                # Add delay to avoid rate limiting
                await asyncio.sleep(
                    random.uniform(
                        self.config['delay_range'][0],
                        self.config['delay_range'][1]
                    )
                )
                
                # Make request
                headers = {'User-Agent': random.choice(self.config['user_agents'])}
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        
                        # Extract data
                        image_url = soup.select_one(selectors['image'])['src']
                        title = soup.select_one(selectors['title']).text.strip()
                        price = soup.select_one(selectors['price']).text.strip()
                        
                        # Download image
                        image_data = await self.download_image(session, image_url)
                        if image_data:
                            # Save image
                            image_filename = f"{url.split('/')[-1]}.jpg"
                            await self.save_image(image_data, image_filename)
                            
                            return {
                                'url': url,
                                'title': title,
                                'price': price,
                                'image_filename': image_filename
                            }
                            
            except Exception as e:
                self.logger.error(f"Error scraping {url}: {str(e)}")
                return None

    async def download_image(
        self,
        session: aiohttp.ClientSession,
        image_url: str
    ) -> bytes:
        """Download image data"""
        try:
            async with session.get(image_url) as response:
                if response.status == 200:
                    return await response.read()
        except Exception as e:
            self.logger.error(f"Error downloading image {image_url}: {str(e)}")
            return None

    async def save_image(self, image_data: bytes, filename: str):
        """Save image data to file"""
        output_dir = Path(self.config['output_dir']) / 'images'
        output_dir.mkdir(parents=True, exist_ok=True)
        
        async with aiofiles.open(output_dir / filename, 'wb') as f:
            await f.write(image_data)

    def save_scrape_results(self, site_url: str, results: List[Dict]):
        """Save scraping results to file"""
        output_dir = Path(self.config['output_dir'])
        output_dir.mkdir(exist_ok=True)
        
        # Save as JSON
        with open(output_dir / 'scrape_results.json', 'w') as f:
            json.dump(results, f, indent=2)
        
        # Save as CSV
        df = pd.DataFrame(results)
        df.to_csv(output_dir / 'scrape_results.csv', index=False)

# Example usage
if __name__ == "__main__":
    # Process local folders
    dataset_manager = JewelryDatasetManager()
    asyncio.run(dataset_manager.process_local_folders('raw_data'))
    
    # Start web scraping
    scraper = JewelryWebScraper()
    asyncio.run(scraper.start_scraping())
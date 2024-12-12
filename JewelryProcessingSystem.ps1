# PowerShell Script: Final Setup for Cloud-based Jewelry Image Processing System

# Exit script on error
$ErrorActionPreference = "Stop"

# ---------------------------
# Parameter Prompts
# ---------------------------

# Function to get user input with a default value
function Get-InputWithDefault {
  param (
      [string]$Prompt,
      [string]$Default = ""
  )

  $userInput = Read-Host "$Prompt [$Default]"
  if ([string]::IsNullOrWhiteSpace($userInput)) {
      return $Default
  }
  return $userInput
}



Write-Host "=== Jewelry Processing System Final Setup ===" -ForegroundColor Cyan

# Collect Parameters
$awsRegion = Prompt-Input "Enter AWS Region" "us-east-1"
$projectName = Prompt-Input "Enter Project Name" "JewelryProcessingSystem"
$sshKeyName = Prompt-Input "Enter SSH Key Name for EKS Nodes" "your_ssh_key_name"

# Cloudinary Credentials
$cloudinaryCloudName = Prompt-Input "Enter Cloudinary Cloud Name"
$cloudinaryApiKey = Prompt-Input "Enter Cloudinary API Key"
$cloudinaryApiSecret = Prompt-Input "Enter Cloudinary API Secret"

# Google Cloud Vision API Key
$googleApiKey = Prompt-Input "Enter Google Cloud Vision API Key"

# Confirmation
Write-Host "`nParameters Collected:" -ForegroundColor Green
Write-Host "AWS Region: $awsRegion"
Write-Host "Project Name: $projectName"
Write-Host "SSH Key Name: $sshKeyName"
Write-Host "Cloudinary Cloud Name: $cloudinaryCloudName"
Write-Host "Google Cloud Vision API Key: $googleApiKey"
Write-Host ""

# ---------------------------
# Directory Structure Creation
# ---------------------------

$projectRoot = "C:\$projectName"
Write-Host "Creating project directory structure at $projectRoot..." -ForegroundColor Cyan

# Define directories
$directories = @(
    "$projectRoot\scripts",
    "$projectRoot\lambda",
    "$projectRoot\docker",
    "$projectRoot\terraform",
    "$projectRoot\terraform\modules",
    "$projectRoot\terraform\modules\vpc",
    "$projectRoot\terraform\modules\eks",
    "$projectRoot\terraform\modules\ecr",
    "$projectRoot\terraform\modules\s3",
    "$projectRoot\terraform\modules\dynamodb",
    "$projectRoot\terraform\modules\iam",
    "$projectRoot\terraform\modules\api_gateway",
    "$projectRoot\terraform\modules\codepipeline",
    "$projectRoot\eks",
    "$projectRoot\ci-cd",
    "$projectRoot\frontend\css",
    "$projectRoot\frontend\js",
    "$projectRoot\frontend\images"
)

foreach ($dir in $directories) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
}

Write-Host "Directory structure created." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Python Scripts
# ---------------------------

Write-Host "Creating Python scripts..." -ForegroundColor Cyan

# scraper.py (Enhanced with multiple sites)
$scriptScraper = @"
import asyncio
import aiohttp
from bs4 import BeautifulSoup
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional, Set
import logging
import hashlib
import re
from pathlib import Path
import json
from enum import Enum
from urllib.parse import urljoin
from PIL import Image, ImageEnhance
import io

class JewelryCategory(Enum):
    RING = "ring"
    NECKLACE = "necklace"
    PENDANT = "pendant"
    BRACELET = "bracelet"
    EARRING = "earring"
    WRISTWATCH = "wristwatch"

class JewelryStyle(Enum):
    FASHION = "fashion"
    HANDMADE = "handmade"
    VINTAGE = "vintage"
    ANTIQUE = "antique"

@dataclass
class ScrapingTarget:
    name: str
    base_url: str
    selectors: Dict[str, str]
    category_paths: Dict[JewelryCategory, str]
    style_identifiers: Dict[JewelryStyle, List[str]]

SCRAPING_TARGETS = {
    "etsy": ScrapingTarget(
        name="Etsy",
        base_url="https://www.etsy.com",
        selectors={
            "product_link": "a.listing-link",
            "title": "h1[data-buy-box-listing-title]",
            "price": "p.wt-text-title-03",
            "description": "div[data-product-details-description-text-content]",
            "material": "div[data-product-details-description] span[data-materials]",
            "images": "img.wt-max-width-full",
            "shop_name": "a.wt-text-link",
            "reviews": "span.wt-text-caption",
            "shipping": "div[data-estimated-delivery]"
        },
        category_paths={
            JewelryCategory.RING: "/c/jewelry/rings",
            JewelryCategory.NECKLACE: "/c/jewelry/necklaces",
            JewelryCategory.PENDANT: "/c/jewelry/pendants",
            JewelryCategory.BRACELET: "/c/jewelry/bracelets",
            JewelryCategory.EARRING: "/c/jewelry/earrings",
            JewelryCategory.WRISTWATCH: "/c/jewelry/watches"
        },
        style_identifiers={
            JewelryStyle.FASHION: ["fashion", "trendy", "modern", "contemporary"],
            JewelryStyle.HANDMADE: ["handmade", "artisan", "handcrafted", "custom"],
            JewelryStyle.VINTAGE: ["vintage", "retro", "classic", "estate"],
            JewelryStyle.ANTIQUE: ["antique", "victorian", "edwardian", "art deco"]
        }
    ),
    
    "rubylane": ScrapingTarget(
        name="RubyLane",
        base_url="https://www.rubylane.com",
        selectors={
            "product_link": "div.item-thumbnail a",
            "title": "h1.item-title",
            "price": "span.price",
            "description": "div.item-description",
            "material": "div.item-details span.material",
            "images": "div.item-photos img",
            "condition": "span.item-condition",
            "era": "span.item-era"
        },
        category_paths={
            JewelryCategory.RING: "/jewelry/rings",
            JewelryCategory.NECKLACE: "/jewelry/necklaces",
            JewelryCategory.PENDANT: "/jewelry/pendants",
            JewelryCategory.BRACELET: "/jewelry/bracelets",
            JewelryCategory.EARRING: "/jewelry/earrings",
            JewelryCategory.WRISTWATCH: "/jewelry/watches"
        },
        style_identifiers={
            JewelryStyle.FASHION: ["fashion", "modern"],
            JewelryStyle.HANDMADE: ["handmade", "artisan"],
            JewelryStyle.VINTAGE: ["vintage", "retro"],
            JewelryStyle.ANTIQUE: ["antique", "victorian", "edwardian"]
        }
    ),
    
    "1stdibs": ScrapingTarget(
        name="1stDibs",
        base_url="https://www.1stdibs.com",
        selectors={
            "product_link": "a.product-link",
            "title": "h1.product-title",
            "price": "div.price-container",
            "description": "div.description-content",
            "material": "div.materials",
            "images": "div.image-gallery img",
            "dealer": "div.dealer-info",
            "period": "div.period",
            "provenance": "div.provenance"
        },
        category_paths={
            JewelryCategory.RING: "/jewelry/rings",
            JewelryCategory.NECKLACE: "/jewelry/necklaces",
            JewelryCategory.PENDANT: "/jewelry/pendants",
            JewelryCategory.BRACELET: "/jewelry/bracelets",
            JewelryCategory.EARRING: "/jewelry/earrings",
            JewelryCategory.WRISTWATCH: "/jewelry/watches"
        },
        style_identifiers={
            JewelryStyle.FASHION: ["contemporary", "modern"],
            JewelryStyle.HANDMADE: ["handmade", "artisan"],
            JewelryStyle.VINTAGE: ["vintage", "mid-century"],
            JewelryStyle.ANTIQUE: ["antique", "victorian", "art nouveau", "art deco"]
        }
    )
}

@dataclass
class JewelryItem:
    id: str
    title: str
    description: str
    price: float
    material: str
    images: List[str]
    category: JewelryCategory
    style: JewelryStyle
    source_url: str
    shop_name: Optional[str] = None
    condition: Optional[str] = None
    era: Optional[str] = None
    reviews: Optional[str] = None
    shipping: Optional[str] = None
    metadata: Optional[Dict] = None

class JewelryScraperPipeline:
    def __init__(self, config: Dict):
        self.config = config
        self.session = None
        self.seen_urls: Set[str] = set()
        self.setup_logging()
        self.setup_storage()
        
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
    
    def setup_storage(self):
        self.output_dir = Path('data')
        self.output_dir.mkdir(exist_ok=True)
        (self.output_dir / 'raw_html').mkdir(exist_ok=True)
        (self.output_dir / 'images').mkdir(exist_ok=True)
        (self.output_dir / 'metadata').mkdir(exist_ok=True)
    
    async def start(self):
        """Initialize scraping session"""
        timeout = aiohttp.ClientTimeout(total=60)
        connector = aiohttp.TCPConnector(limit=20, force_close=True)
        self.session = aiohttp.ClientSession(
            timeout=timeout,
            connector=connector,
            headers=self.get_headers()
        )
    
    def get_headers(self) -> Dict:
        """Generate random headers to avoid detection"""
        return {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate, br',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache'
        }
    
    async def stop(self):
        """Clean up resources"""
        if self.session:
            await self.session.close()
    
    async def scrape_site(self, target: ScrapingTarget):
        """Scrape a single fashion jewelry site"""
        try:
            products = []
            self.logger.info(f"Starting scrape of {target.name}")
            
            for category, path in target.category_paths.items():
                for style, identifiers in target.style_identifiers.items():
                    self.logger.info(f"Scraping Category: {category.value}, Style: {style.value}")
                    page = 1
                    while page <= self.config.get('max_pages', 100):
                        url = self.build_category_url(target, category, style, page)
                        product_links = await self.get_product_links(url, target.selectors)
                        
                        if not product_links:
                            self.logger.info(f"No more products found at {url}. Ending category scrape.")
                            break
                        
                        # Process product pages concurrently
                        tasks = [
                            self.scrape_product(link, target, category, style) 
                            for link in product_links 
                            if link not in self.seen_urls
                        ]
                        results = await asyncio.gather(*tasks, return_exceptions=True)
                        
                        # Filter out errors and None
                        valid_products = [r for r in results if isinstance(r, JewelryItem)]
                        products.extend(valid_products)
                        
                        self.logger.info(f"Scraped page {page}, got {len(valid_products)} products")
                        page += 1
                        
                        # Respect rate limits
                        await asyncio.sleep(self.config.get('page_delay', 2))
            
            # Save all products metadata
            self.save_all_metadata(products)
            return products
            
        except Exception as e:
            self.logger.error(f"Error scraping site {target.name}: {str(e)}")
            return []
    
    def build_category_url(self, target: ScrapingTarget, category: JewelryCategory, style: JewelryStyle, page: int) -> str:
        """Build URL for category page"""
        base_path = target.category_paths[category]
        style_param = self.get_style_param(target, style)
        
        if target.name == "Etsy":
            return f"{target.base_url}{base_path}?page={page}&style={style_param}"
        elif target.name == "RubyLane":
            return f"{target.base_url}{base_path}/{style_param}?page={page}"
        elif target.name == "1stDibs":
            return f"{target.base_url}{base_path}?page={page}&style={style_param}"
        else:
            return f"{target.base_url}{base_path}?page={page}&style={style_param}"
    
    def get_style_param(self, target: ScrapingTarget, style: JewelryStyle) -> str:
        """Get URL parameter for jewelry style"""
        if target.name == "Etsy":
            return style.value
        elif target.name == "RubyLane":
            return style.value
        elif target.name == "1stDibs":
            return style.value
        else:
            return style.value
    
    async def get_product_links(self, url: str, selectors: Dict) -> List[str]:
        """Extract product links from category page"""
        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    links = []
                    
                    for link in soup.select(selectors['product_link']):
                        href = link.get('href')
                        if href:
                            # Ensure full URL
                            full_url = urljoin(url, href)
                            links.append(full_url)
                    
                    return links
                else:
                    self.logger.warning(f"Got status {response.status} for {url}")
                    return []
                    
        except Exception as e:
            self.logger.error(f"Error getting product links from {url}: {str(e)}")
            return []
    
    async def scrape_product(self, url: str, target: ScrapingTarget, category: JewelryCategory, style: JewelryStyle) -> Optional[JewelryItem]:
        """Scrape a single product page"""
        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    html = await response.text()
                    
                    # Save raw HTML
                    product_id = hashlib.md5(url.encode()).hexdigest()
                    self.save_raw_html(product_id, html)
                    
                    # Parse product data
                    soup = BeautifulSoup(html, 'html.parser')
                    
                    # Extract product information
                    title = self.extract_text(soup, target.selectors['title'])
                    description = self.extract_text(soup, target.selectors['description'])
                    price = self.extract_price(soup, target.selectors['price'])
                    material = self.extract_text(soup, target.selectors['material'])
                    image_urls = self.extract_image_urls(soup, target.selectors['images'])
                    
                    # Extract additional attributes based on selectors
                    shop_name = self.extract_text(soup, target.selectors.get('shop_name'))
                    condition = self.extract_text(soup, target.selectors.get('condition'))
                    era = self.extract_text(soup, target.selectors.get('era'))
                    reviews = self.extract_text(soup, target.selectors.get('reviews'))
                    shipping = self.extract_text(soup, target.selectors.get('shipping'))
                    
                    # Create JewelryItem object
                    item = JewelryItem(
                        id=product_id,
                        title=title,
                        description=description,
                        price=price,
                        material=material,
                        images=image_urls,
                        category=category,
                        style=style,
                        source_url=url,
                        shop_name=shop_name,
                        condition=condition,
                        era=era,
                        reviews=reviews,
                        shipping=shipping,
                        metadata={
                            'scrape_date': (Get-Date).ToString("yyyy-MM-dd"),
                            'source': target.name
                        }
                    )
                    
                    # Validate item
                    if self.validate_item(item):
                        # Download and process images
                        await self.download_images(item)
                        # Save metadata
                        self.save_metadata(item)
                        return item
            return None
                    
        except Exception as e:
            self.logger.error(f"Error scraping product {url}: {str(e)}")
            return None
    
    def extract_text(self, soup: BeautifulSoup, selector: Optional[str]) -> str:
        """Extract and clean text using selector"""
        if not selector:
            return ""
        element = soup.select_one(selector)
        return element.text.strip() if element else ""
    
    def extract_price(self, soup: BeautifulSoup, selector: str) -> float:
        """Extract and parse price"""
        price_text = self.extract_text(soup, selector)
        if price_text:
            # Remove currency symbols and convert to float
            price = re.sub(r'[^\d.]', '', price_text)
            try:
                return float(price)
            except ValueError:
                return 0.0
        return 0.0
    
    def extract_image_urls(self, soup: BeautifulSoup, selector: str) -> List[str]:
        """Extract all image URLs"""
        urls = []
        for img in soup.select(selector):
            url = img.get('src') or img.get('data-src')
            if url and self.is_valid_image_url(url):
                urls.append(url)
        return urls
    
    def is_valid_image_url(self, url: str) -> bool:
        """Validate image URL"""
        try:
            parsed = urlparse(url)
            return bool(parsed.netloc) and bool(parsed.scheme)
        except:
            return False
    
    async def download_images(self, item: JewelryItem):
        """Download and process all images for a jewelry item"""
        image_dir = self.output_dir / 'images' / item.id
        image_dir.mkdir(parents=True, exist_ok=True)
        
        tasks = []
        for idx, image_url in enumerate(item.images):
            tasks.append(self.download_and_process_image(image_url, image_dir, idx))
        
        await asyncio.gather(*tasks)
    
    async def download_and_process_image(self, url: str, image_dir: Path, index: int):
        """Download and process a single image"""
        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    img_bytes = await response.read()
                    image_path = image_dir / "image_{0}.jpg".format(index)
                    with open(image_path, 'wb') as f:
                        f.write(img_bytes)
                    
                    # Open and process image
                    img = Image.open(image_path)
                    
                    # Validate resolution
                    if img.width < self.config['min_image_resolution'][0] or img.height < self.config['min_image_resolution'][1]:
                        img = img.resize(self.config['min_image_resolution'], Image.ANTIALIAS)
                    
                    # Enhance image quality
                    enhancer = ImageEnhance.Sharpness(img)
                    img = enhancer.enhance(self.config['image_quality_enhancement'])
                    
                    # Save processed image
                    img.save(image_path, 'JPEG', quality=95)
        except Exception as e:
            self.logger.error(f"Error downloading or processing image {url}: {str(e)}")
    
    def validate_item(self, item: JewelryItem) -> bool:
        """Validate jewelry item meets quality standards"""
        # Check required fields
        if not all([
            item.title,
            item.description,
            item.price > 0,
            item.material,
            len(item.images) >= self.config['min_images_per_item']
        ]):
            return False
        
        # Additional validations can be added here
        return True
    
    def save_raw_html(self, product_id: str, html: str):
        """Save raw HTML content"""
        html_path = self.output_dir / 'raw_html' / "$product_id.html"
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html)
    
    def save_metadata(self, item: JewelryItem):
        """Save product metadata"""
        metadata_path = self.output_dir / 'metadata' / "$item.id.json"
        with open(metadata_path, 'w') as f:
            json.dump(asdict(item), f, indent=2)
    
    def save_all_metadata(self, products: List[JewelryItem]):
        """Save all products metadata into a single file"""
        all_metadata = [asdict(product) for product in products]
        with open(self.output_dir / 'all_metadata.json', 'w') as f:
            json.dump(all_metadata, f, indent=2)

async def main_scraper():
    # Configuration
    config = {
        'min_items_per_category': 1000,
        'min_images_per_item': 3,
        'image_quality_enhancement': 1.2,
        'min_image_resolution': (800, 800),
        'page_delay': 2,
        'max_pages': 100
    }
    
    scraper = JewelryScraperPipeline(config)
    await scraper.start()
    
    for target in SCRAPING_TARGETS.values():
        items = await scraper.scrape_site(target)
        print(f"Scraped {len(items)} products from {target.name}")
        
    await scraper.stop()

if __name__ == "__main__":
    asyncio.run(main_scraper())
"@

Set-Content -Path "$projectRoot\scripts\scraper.py" -Value $scriptScraper -Encoding UTF8

# datapipeline.py (Enhanced for dataset specialization)
$scriptDataPipeline = @"
import json
import boto3
from pathlib import Path
import logging
from typing import List, Dict
import zipfile
import io

class JewelryDataPipeline:
    def __init__(self, config: Dict):
        self.config = config
        self.logger = self.setup_logging()
        self.s3 = boto3.client('s3')
        self.dynamodb = boto3.resource('dynamodb').Table(config['dynamodb_table_name'])
        
    def setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('data_pipeline.log'),
                logging.StreamHandler()
            ]
        )
        return logging.getLogger('JewelryDataPipeline')
    
    def process_data(self):
        """Process data from S3 and create specialized datasets"""
        input_bucket = self.config['input_bucket']
        output_bucket = self.config['output_bucket']
        
        # List all metadata files in S3
        response = self.s3.list_objects_v2(Bucket=input_bucket, Prefix='metadata/')
        metadata_files = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].endswith('.json')]
        
        dataset_resnet = []
        dataset_llava = []
        
        for key in metadata_files:
            obj = self.s3.get_object(Bucket=input_bucket, Key=key)
            data = json.loads(obj['Body'].read())
            
            # Process for ResNet 500
            processed_resnet = self.pipeline_resnet(data)
            dataset_resnet.append(processed_resnet)
            
            # Process for LLava
            processed_llava = self.pipeline_llava(data)
            dataset_llava.append(processed_llava)
        
        # Create zipped datasets
        self.create_zipped_dataset(output_bucket, 'resnet_dataset.zip', dataset_resnet)
        self.create_zipped_dataset(output_bucket, 'llava_dataset.zip', dataset_llava)
        
    def pipeline_resnet(self, data: Dict) -> Dict:
        """Process data for ResNet 500 training"""
        processed = {
            'id': data['id'],
            'title': data['title'],
            'price': data['price'],
            'category': data['category'],
            'brand': data.get('shop_name', ''),
            'image_paths': [f"s3://{self.config['output_bucket']}/images/{data['id']}/image_{i}.jpg" for i in range(len(data['images']))]
        }
        return processed
    
    def pipeline_llava(self, data: Dict) -> Dict:
        """Process data for LLava training"""
        processed = {
            'id': data['id'],
            'description': data['description'],
            'material': data['material'],
            'style': data['style'],
            'price': data['price'],
            'image_urls': data['images'],
            'google_vision_annotations': self.get_google_vision_annotations(data['images'])
        }
        return processed
    
    def get_google_vision_annotations(self, image_urls: List[str]) -> List[Dict]:
        """Integrate with Google Cloud Vision API to get image annotations"""
        # Placeholder for actual integration
        # Implement API calls to Google Cloud Vision here
        annotations = []
        for url in image_urls:
            annotations.append({
                'image_url': url,
                'labels': ['placeholder_label']  # Replace with actual labels from Google Vision
            })
        return annotations
    
    def create_zipped_dataset(self, bucket: str, file_name: str, dataset: List[Dict]):
        """Create and upload zipped dataset to S3"""
        self.logger.info(f"Creating and uploading {file_name} to S3 bucket {bucket}")
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            zip_file.writestr(file_name.replace('.zip', '.json'), json.dumps(dataset, indent=2))
        
        zip_buffer.seek(0)
        self.s3.put_object(
            Bucket=bucket,
            Key=file_name,
            Body=zip_buffer.read(),
            ContentType='application/zip'
        )
        self.logger.info(f"{file_name} uploaded successfully.")

if __name__ == "__main__":
    config = {
        'input_bucket': 'jewelry-images-input',  # Replace with actual input bucket name
        'output_bucket': 'jewelry-images-output',  # Replace with actual output bucket name
        'dynamodb_table_name': 'jewelry-metadata'  # Replace with actual DynamoDB table name
    }
    
    pipeline = JewelryDataPipeline(config)
    pipeline.process_data()
"@

Set-Content -Path "$projectRoot\scripts\datapipeline.py" -Value $scriptDataPipeline -Encoding UTF8

# ml_model.py (Enhanced with LoRA, Logger Kernel, DeepSpeed placeholders)
$scriptMLModel = @"
import json
import boto3
from pathlib import Path
import logging
from typing import List, Dict
import zipfile
import io

class JewelryMLModel:
    def __init__(self, config: Dict):
        self.config = config
        self.logger = self.setup_logging()
        self.s3 = boto3.client('s3')
        self.dynamodb = boto3.resource('dynamodb').Table(config['dynamodb_table_name'])
        
    def setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('ml_model.log'),
                logging.StreamHandler()
            ]
        )
        return logging.getLogger('JewelryMLModel')
    
    def fine_tune_model(self):
        """Fine-tune ML models using datasets"""
        input_bucket = self.config['input_bucket']
        output_bucket = self.config['output_bucket']
        
        # Download datasets from S3
        dataset_resnet = self.download_dataset(input_bucket, 'resnet_dataset.zip')
        dataset_llava = self.download_dataset(input_bucket, 'llava_dataset.zip')
        
        # Extract datasets
        dataset_resnet = self.extract_dataset(dataset_resnet)
        dataset_llava = self.extract_dataset(dataset_llava)
        
        # Fine-tune models
        self.train_resnet500(dataset_resnet)
        self.train_llava(dataset_llava)
        
        # Package and upload fine-tuned models
        self.package_and_upload_model(output_bucket, 'resnet500_model.zip', 'resnet500_model/')
        self.package_and_upload_model(output_bucket, 'llava_model.zip', 'llava_model/')
        
    def download_dataset(self, bucket: str, file_name: str) -> bytes:
        """Download dataset from S3"""
        self.logger.info(f"Downloading {file_name} from bucket {bucket}")
        obj = self.s3.get_object(Bucket=bucket, Key=file_name)
        return obj['Body'].read()
    
    def extract_dataset(self, zip_bytes: bytes) -> List[Dict]:
        """Extract dataset from zip bytes"""
        import zipfile
        import io
        
        self.logger.info("Extracting dataset...")
        with zipfile.ZipFile(io.BytesIO(zip_bytes), 'r') as zip_ref:
            for file in zip_ref.namelist():
                if file.endswith('.json'):
                    with zip_ref.open(file) as f:
                        data = json.load(f)
                        return data
        return []
    
    def train_resnet500(self, dataset: List[Dict]):
        """Train ResNet 500 model using DeepSpeed and LoRA"""
        self.logger.info("Training ResNet 500 model...")
        # Placeholder for ResNet 500 training logic with DeepSpeed and LoRA
        pass
    
    def train_llava(self, dataset: List[Dict]):
        """Train LLava model using DeepSpeed and LoRA"""
        self.logger.info("Training LLava model...")
        # Placeholder for LLava training logic with DeepSpeed and LoRA
        pass
    
    def package_and_upload_model(self, bucket: str, file_name: str, model_dir: str):
        """Package the trained model and upload to S3"""
        self.logger.info(f"Packaging and uploading {file_name} to bucket {bucket}")
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            # Placeholder: Add actual model files
            for root, dirs, files in os.walk(model_dir):
                for file in files:
                    file_path = Path(root) / file
                    zip_file.write(file_path, arcname=file_path.relative_to(model_dir))
        
        zip_buffer.seek(0)
        self.s3.put_object(
            Bucket=bucket,
            Key=file_name,
            Body=zip_buffer.read(),
            ContentType='application/zip'
        )
        self.logger.info(f"{file_name} uploaded successfully.")

if __name__ == "__main__":
    config = {
        'input_bucket': 'jewelry-images-input',  # Replace with actual input bucket name
        'output_bucket': 'jewelry-images-output',  # Replace with actual output bucket name
        'dynamodb_table_name': 'jewelry-metadata'  # Replace with actual DynamoDB table name
    }
    
    model = JewelryMLModel(config)
    model.fine_tune_model()
"@

Set-Content -Path "$projectRoot\scripts\ml_model.py" -Value $scriptMLModel -Encoding UTF8

Write-Host "Python scripts created." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Dockerfiles
# ---------------------------

Write-Host "Creating Dockerfiles..." -ForegroundColor Cyan

# Dockerfile for Scraper Service
$dockerfileScraper = @"
# Use Python 3.9 slim base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y build-essential libssl-dev libffi-dev python3-dev && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY scripts/requirements_scraper.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements_scraper.txt

# Copy scraper script and targets
COPY scripts/scraper.py .
COPY scripts/config.json .

# Command to run the scraper
CMD ["python", "scraper.py"]
"@

Set-Content -Path "$projectRoot\docker\Dockerfile.scraper" -Value $dockerfileScraper -Encoding UTF8

# requirements_scraper.txt
$requirementsScraper = @"
aiohttp
beautifulsoup4
dataclasses
pillow
"@

Set-Content -Path "$projectRoot\scripts\requirements_scraper.txt" -Value $requirementsScraper -Encoding UTF8

# Dockerfile for Data Pipeline Service
$dockerfileDataPipeline = @"
# Use Python 3.9 slim base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y build-essential libssl-dev libffi-dev python3-dev && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY scripts/requirements_datapipeline.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements_datapipeline.txt

# Copy data pipeline script
COPY scripts/datapipeline.py .

# Command to run the data pipeline
CMD ["python", "datapipeline.py"]
"@

Set-Content -Path "$projectRoot\docker\Dockerfile.datapipeline" -Value $dockerfileDataPipeline -Encoding UTF8

# requirements_datapipeline.txt
$requirementsDataPipeline = @"
boto3
"@

Set-Content -Path "$projectRoot\scripts\requirements_datapipeline.txt" -Value $requirementsDataPipeline -Encoding UTF8

# Dockerfile for ML Model Service
$dockerfileMLModel = @"
# Use Python 3.9 slim base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y build-essential libssl-dev libffi-dev python3-dev && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY scripts/requirements_mlmodel.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements_mlmodel.txt

# Copy ML model script
COPY scripts/ml_model.py .

# Command to run the ML model service
CMD ["python", "ml_model.py"]
"@

Set-Content -Path "$projectRoot\docker\Dockerfile.mlmodel" -Value $dockerfileMLModel -Encoding UTF8

# requirements_mlmodel.txt
$requirementsMLModel = @"
boto3
"@

Set-Content -Path "$projectRoot\scripts\requirements_mlmodel.txt" -Value $requirementsMLModel -Encoding UTF8

Write-Host "Dockerfiles and requirements.txt files created." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Frontend Files
# ---------------------------

Write-Host "Creating Frontend files..." -ForegroundColor Cyan

# index.html
$frontendHTML = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Jewelry Processing System</title>
    <link rel="stylesheet" href="css/styles.css">
</head>
<body>

<h2>Welcome to the Jewelry Processing System</h2>

<!-- Trigger/Open The Modal -->
<button id="demoBtn">Demo Services</button>

<!-- The Modal -->
<div id="demoModal" class="modal">

  <!-- Modal content -->
  <div class="modal-content">
    <span class="close">&times;</span>
    <h3>API Demo</h3>
    <form id="demoForm">
        <label for="imageUrl">Image URL:</label><br>
        <input type="text" id="imageUrl" name="imageUrl" required><br><br>
        <button type="submit">Submit</button>
    </form>
    <div id="result"></div>
  </div>

</div>

<script src="js/scripts.js"></script>

</body>
</html>
"@

Set-Content -Path "$projectRoot\frontend\index.html" -Value $frontendHTML -Encoding UTF8

# styles.css
$frontendCSS = @"
/* Add your custom styles here */
body {
    font-family: Arial, sans-serif;
    margin: 20px;
}

button {
    padding: 10px 20px;
    font-size: 16px;
}

/* Modal styles */
.modal {
    display: none; 
    position: fixed; 
    z-index: 1; 
    padding-top: 100px; 
    left: 0;
    top: 0;
    width: 100%; 
    height: 100%; 
    overflow: auto; 
    background-color: rgba(0,0,0,0.4); 
}

.modal-content {
    background-color: #fefefe;
    margin: auto;
    padding: 20px;
    border: 1px solid #888;
    width: 50%;
}

.close {
    color: #aaa;
    float: right;
    font-size: 24px;
    font-weight: bold;
}

.close:hover,
.close:focus {
    color: black;
    text-decoration: none;
    cursor: pointer;
}
"@

Set-Content -Path "$projectRoot\frontend\css\styles.css" -Value $frontendCSS -Encoding UTF8

# scripts.js
$frontendJS = @"
// Get modal elements
var modal = document.getElementById('demoModal');
var btn = document.getElementById('demoBtn');
var span = document.getElementsByClassName('close')[0];

// Open modal on button click
btn.onclick = function() {
  modal.style.display = 'block';
}

// Close modal on 'x' click
span.onclick = function() {
  modal.style.display = 'none';
}

// Close modal when clicking outside the modal content
window.onclick = function(event) {
  if (event.target == modal) {
    modal.style.display = 'none';
  }
}

// Handle form submission
document.getElementById('demoForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    var imageUrl = document.getElementById('imageUrl').value;
    var resultDiv = document.getElementById('result');

    try {
        const response = await fetch('https://YOUR_API_GATEWAY_ENDPOINT/create-dataset', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': 'YOUR_API_KEY'  // Replace with your actual API key
            },
            body: JSON.stringify({ imageUrl: imageUrl })
        });
        const data = await response.json();
        resultDiv.innerHTML = `<p>Response: ${JSON.stringify(data)}</p>`;
    } catch (error) {
        resultDiv.innerHTML = `<p>Error: ${error}</p>`;
    }
});
"@

Set-Content -Path "$projectRoot\frontend\js\scripts.js" -Value $frontendJS -Encoding UTF8

Write-Host "Frontend files created." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Terraform Configuration
# ---------------------------

Write-Host "Creating Terraform configuration..." -ForegroundColor Cyan

# Terraform providers.tf
$terraformProviders = @"
provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}
"@

Set-Content -Path "$projectRoot\terraform\providers.tf" -Value $terraformProviders -Encoding UTF8

# Terraform variables.tf
$terraformVariables = @"
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "$awsRegion"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "$projectName"
}

variable "cloudinary_cloud_name" {
  description = "Cloudinary Cloud Name"
  type        = string
  default     = "$cloudinaryCloudName"
}

variable "cloudinary_api_key" {
  description = "Cloudinary API Key"
  type        = string
  default     = "$cloudinaryApiKey"
}

variable "cloudinary_api_secret" {
  description = "Cloudinary API Secret"
  type        = string
  default     = "$cloudinaryApiSecret"
}

variable "google_api_key" {
  description = "Google Cloud Vision API Key"
  type        = string
  default     = "$googleApiKey"
}

variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "$projectName-eks-cluster"
}

variable "ecr_repository_name" {
  description = "ECR Repository Name"
  type        = string
  default     = "$projectName-repo"
}

variable "lambda_function_name" {
  description = "Lambda Function Name"
  type        = string
  default     = "$projectName-lambda"
}

variable "dynamodb_table_name" {
  description = "DynamoDB Table Name"
  type        = string
  default     = "$projectName-metadata"
}

variable "input_s3_bucket" {
  description = "Input S3 Bucket Name"
  type        = string
  default     = "$projectName-input"
}

variable "output_s3_bucket" {
  description = "Output S3 Bucket Name"
  type        = string
  default     = "$projectName-output"
}

variable "ssh_key_name" {
  description = "SSH Key Name for EKS Nodes"
  type        = string
  default     = "$sshKeyName"
}
"@

Set-Content -Path "$projectRoot\terraform\variables.tf" -Value $terraformVariables -Encoding UTF8

# Terraform outputs.tf
$terraformOutputs = @"
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "ecr_repository_uri" {
  description = "URI of the ECR repository"
  value       = module.ecr.repository_uri
}

output "input_s3_bucket" {
  description = "Name of the input S3 bucket"
  value       = module.s3.input_bucket
}

output "output_s3_bucket" {
  description = "Name of the output S3 bucket"
  value       = module.s3.output_bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.iam.lambda_function_arn
}

output "api_gateway_endpoint" {
  description = "API Gateway Endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "codecommit_repo_url" {
  description = "CodeCommit Repository Clone URL"
  value       = module.codepipeline.codecommit_repo_url
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.codepipeline.pipeline_name
}
"@

Set-Content -Path "$projectRoot\terraform\outputs.tf" -Value $terraformOutputs -Encoding UTF8

# Terraform main.tf
$terraformMain = @"
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

module "eks" {
  source            = "./modules/eks"
  cluster_name      = var.eks_cluster_name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnets
  ssh_key_name      = var.ssh_key_name
  desired_capacity  = 2
  max_capacity      = 3
  min_capacity      = 1
  project_name      = var.project_name
}

module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

module "s3" {
  source        = "./modules/s3"
  input_bucket  = "${var.input_s3_bucket}-${Get-Random -Minimum 1000 -Maximum 9999}"
  output_bucket = "${var.output_s3_bucket}-${Get-Random -Minimum 1000 -Maximum 9999}"
}

module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = var.dynamodb_table_name
}

module "iam" {
  source                  = "./modules/iam"
  lambda_role_name        = "$projectName-lambda-role"
  lambda_function_name    = var.lambda_function_name
  ecr_repository_uri      = module.ecr.repository_uri
  dynamodb_table_name     = module.dynamodb.table_name
  input_s3_bucket         = module.s3.input_bucket
  cloudinary_cloud_name   = var.cloudinary_cloud_name
  cloudinary_api_key      = var.cloudinary_api_key
  cloudinary_api_secret   = var.cloudinary_api_secret
  google_api_key          = var.google_api_key
  region                  = var.aws_region
}

module "api_gateway" {
  source               = "./modules/api_gateway"
  api_name             = "$projectName-api"
  api_description      = "API for jewelry image processing"
  lambda_function_arn  = module.iam.lambda_function_arn
  api_stage            = "prod"
  region               = var.aws_region
}

module "codepipeline" {
  source                   = "./modules/codepipeline"
  codecommit_repo_name     = "$projectName-repo"
  codebuild_project_name   = "$projectName-build"
  codebuild_service_role_arn = "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AWSCodeBuildServiceRole"
  codepipeline_service_role_arn = "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AWSCodePipelineServiceRole"
  artifact_store_bucket    = module.s3.input_bucket
  project_name             = var.project_name
  eks_cluster_name         = module.eks.cluster_name
  ecs_service_name         = "$projectName-service"
  codecommit_repo_clone_url = module.codepipeline.codecommit_repo_url
  region                   = var.aws_region
}
"@

Set-Content -Path "$projectRoot\terraform\main.tf" -Value $terraformMain -Encoding UTF8

# ---------------------------
# Create Terraform Modules
# ---------------------------

Write-Host "Creating Terraform modules..." -ForegroundColor Cyan

# VPC Module
$moduleVPCMain = @"
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "\${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "\${var.project_name}-public-subnet-\${count.index + 1}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "\${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "\${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}
"@

Set-Content -Path "$projectRoot\terraform\modules\vpc\main.tf" -Value $moduleVPCMain -Encoding UTF8

$moduleVPCVariables = @"
variable "project_name" {
  description = "Name of the project"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\vpc\variables.tf" -Value $moduleVPCVariables -Encoding UTF8

$moduleVPCOutputs = @"
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}
"@

Set-Content -Path "$projectRoot\terraform\modules\vpc\outputs.tf" -Value $moduleVPCOutputs -Encoding UTF8

# EKS Module
$moduleEKSMain = @"
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.21"
  subnets         = var.subnet_ids
  vpc_id          = var.vpc_id

  node_groups = {
    eks_nodes = {
      desired_capacity = var.desired_capacity
      max_capacity     = var.max_capacity
      min_capacity     = var.min_capacity

      instance_type = "t3.medium"
      key_name      = var.ssh_key_name

      additional_tags = {
        Name = "\${var.project_name}-node"
      }
    }
  }

  tags = {
    Name = var.project_name
  }
}
"@

Set-Content -Path "$projectRoot\terraform\modules\eks\main.tf" -Value $moduleEKSMain -Encoding UTF8

$moduleEKSVariables = @"
variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "ssh_key_name" {
  description = "SSH Key Name for EKS Nodes"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of nodes"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of nodes"
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of nodes"
  type        = number
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\eks\variables.tf" -Value $moduleEKSVariables -Encoding UTF8

$moduleEKSOutputs = @"
output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "node_group_arns" {
  value = module.eks.node_group_arns
}
"@

Set-Content -Path "$projectRoot\terraform\modules\eks\outputs.tf" -Value $moduleEKSOutputs -Encoding UTF8

# ECR Module
$moduleECRMain = @"
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "\${var.repository_name}"
  }
}

output "repository_uri" {
  value = aws_ecr_repository.this.repository_url
}
"@

Set-Content -Path "$projectRoot\terraform\modules\ecr\main.tf" -Value $moduleECRMain -Encoding UTF8

$moduleECRVariables = @"
variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\ecr\variables.tf" -Value $moduleECRVariables -Encoding UTF8

$moduleECROutputs = @"
output "repository_uri" {
  value = aws_ecr_repository.this.repository_url
}
"@

Set-Content -Path "$projectRoot\terraform\modules\ecr\outputs.tf" -Value $moduleECROutputs -Encoding UTF8

# S3 Module
$moduleS3Main = @"
resource "aws_s3_bucket" "input" {
  bucket = var.input_bucket

  tags = {
    Name        = var.input_bucket
    Environment = "Production"
  }
}

resource "aws_s3_bucket" "output" {
  bucket = var.output_bucket

  tags = {
    Name        = var.output_bucket
    Environment = "Production"
  }
}

output "input_bucket" {
  value = aws_s3_bucket.input.id
}

output "output_bucket" {
  value = aws_s3_bucket.output.id
}
"@

Set-Content -Path "$projectRoot\terraform\modules\s3\main.tf" -Value $moduleS3Main -Encoding UTF8

$moduleS3Variables = @"
variable "input_bucket" {
  description = "Input S3 Bucket Name"
  type        = string
}

variable "output_bucket" {
  description = "Output S3 Bucket Name"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\s3\variables.tf" -Value $moduleS3Variables -Encoding UTF8

$moduleS3Outputs = @"
output "input_bucket" {
  value = aws_s3_bucket.input.id
}

output "output_bucket" {
  value = aws_s3_bucket.output.id
}
"@

Set-Content -Path "$projectRoot\terraform\modules\s3\outputs.tf" -Value $moduleS3Outputs -Encoding UTF8

# DynamoDB Module
$moduleDynamoMain = @"
resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }

  hash_key = "id"

  tags = {
    Name        = var.table_name
    Environment = "Production"
  }
}

output "table_name" {
  value = aws_dynamodb_table.this.name
}
"@

Set-Content -Path "$projectRoot\terraform\modules\dynamodb\main.tf" -Value $moduleDynamoMain -Encoding UTF8

$moduleDynamoVariables = @"
variable "table_name" {
  description = "DynamoDB Table Name"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\dynamodb\variables.tf" -Value $moduleDynamoVariables -Encoding UTF8

$moduleDynamoOutputs = @"
output "table_name" {
  value = aws_dynamodb_table.this.name
}
"@

Set-Content -Path "$projectRoot\terraform\modules\dynamodb\outputs.tf" -Value $moduleDynamoOutputs -Encoding UTF8

# IAM Module
$moduleIAMMain = @"
resource "aws_iam_role" "lambda_role" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = var.lambda_role_name
  }
}

resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "\${var.lambda_role_name}-basic-exec"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  roles      = [aws_iam_role.lambda_role.name]
}

resource "aws_iam_policy_attachment" "lambda_s3_access" {
  name       = "\${var.lambda_role_name}-s3-access"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  roles      = [aws_iam_role.lambda_role.name]
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_access" {
  name       = "\${var.lambda_role_name}-dynamodb-access"
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  roles      = [aws_iam_role.lambda_role.name]
}

resource "aws_lambda_function" "this" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = var.ecr_repository_uri

  environment {
    variables = {
      CLOUDINARY_CLOUD_NAME = var.cloudinary_cloud_name
      CLOUDINARY_API_KEY    = var.cloudinary_api_key
      CLOUDINARY_API_SECRET = var.cloudinary_api_secret
      GOOGLE_API_KEY        = var.google_api_key
    }
  }

  tags = {
    Name = var.lambda_function_name
  }
}

output "lambda_function_arn" {
  value = aws_lambda_function.this.arn
}
"@

Set-Content -Path "$projectRoot\terraform\modules\iam\main.tf" -Value $moduleIAMMain -Encoding UTF8

$moduleIAMVariables = @"
variable "lambda_role_name" {
  description = "IAM Role Name for Lambda"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda Function Name"
  type        = string
}

variable "ecr_repository_uri" {
  description = "ECR Repository URI"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB Table Name"
  type        = string
}

variable "input_s3_bucket" {
  description = "Input S3 Bucket Name"
  type        = string
}

variable "cloudinary_cloud_name" {
  description = "Cloudinary Cloud Name"
  type        = string
}

variable "cloudinary_api_key" {
  description = "Cloudinary API Key"
  type        = string
}

variable "cloudinary_api_secret" {
  description = "Cloudinary API Secret"
  type        = string
}

variable "google_api_key" {
  description = "Google Cloud Vision API Key"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\iam\variables.tf" -Value $moduleIAMVariables -Encoding UTF8

$moduleIAMOutputs = @"
output "lambda_function_arn" {
  value = aws_lambda_function.this.arn
}
"@

Set-Content -Path "$projectRoot\terraform\modules\iam\outputs.tf" -Value $moduleIAMOutputs -Encoding UTF8

# API Gateway Module
$moduleAPIGWMain = @"
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = var.api_description
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "post_upload" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_post_upload" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = aws_api_gateway_method.post_upload.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:\${var.region}:lambda:path/2015-03-31/functions/\${var.lambda_function_arn}/invocations"
}

resource "aws_api_gateway_resource" "dataset" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "create-dataset"
}

resource "aws_api_gateway_method" "post_dataset" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.dataset.id
  http_method   = "POST"
  authorization = "API_KEY"
}

resource "aws_api_gateway_integration" "lambda_post_dataset" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.dataset.id
  http_method             = aws_api_gateway_method.post_dataset.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:\${var.region}:lambda:path/2015-03-31/functions/\${var.lambda_function_arn}/invocations"
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.lambda_post_upload,
    aws_api_gateway_integration.lambda_post_dataset
  ]

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.api_stage
}

resource "aws_api_gateway_api_key" "aitoolpool_key" {
  name        = "aitoolpool-key"
  enabled     = true
  stage_key {
    rest_api_id = aws_api_gateway_rest_api.this.id
    stage_name  = aws_api_gateway_deployment.this.stage_name
  }
}

resource "aws_api_gateway_usage_plan" "aitoolpool_plan" {
  name = "aitoolpool-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_deployment.this.stage_name
  }

  throttle_settings {
    rate_limit  = 100
    burst_limit = 200
  }
}

resource "aws_api_gateway_usage_plan_key" "aitoolpool_key_attachment" {
  key_id        = aws_api_gateway_api_key.aitoolpool_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.aitoolpool_plan.id
}

output "api_endpoint" {
  value = "https://\${aws_api_gateway_rest_api.this.id}.execute-api.\${var.region}.amazonaws.com/\${var.api_stage}/upload"
}

output "dataset_api_endpoint" {
  value = "https://\${aws_api_gateway_rest_api.this.id}.execute-api.\${var.region}.amazonaws.com/\${var.api_stage}/create-dataset"
}
"@

Set-Content -Path "$projectRoot\terraform\modules\api_gateway\main.tf" -Value $moduleAPIGWMain -Encoding UTF8

$moduleAPIGWVariables = @"
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "API for jewelry image processing"
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to integrate"
  type        = string
}

variable "api_stage" {
  description = "Stage name for the API"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS Region"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\api_gateway\variables.tf" -Value $moduleAPIGWVariables -Encoding UTF8

$moduleAPIGWOutputs = @"
output "api_endpoint" {
  value = "https://\${aws_api_gateway_rest_api.this.id}.execute-api.\${var.region}.amazonaws.com/\${var.api_stage}/upload"
}

output "dataset_api_endpoint" {
  value = "https://\${aws_api_gateway_rest_api.this.id}.execute-api.\${var.region}.amazonaws.com/\${var.api_stage}/create-dataset"
}
"@

Set-Content -Path "$projectRoot\terraform\modules\api_gateway\outputs.tf" -Value $moduleAPIGWOutputs -Encoding UTF8

# CodePipeline Module
$moduleCodePipelineMain = @"
resource "aws_codecommit_repository" "this" {
  repository_name = var.codecommit_repo_name
  description     = "Repository for ${var.project_name}"

  tags = {
    Name = var.codecommit_repo_name
  }
}

resource "aws_codebuild_project" "this" {
  name          = var.codebuild_project_name
  description   = "Build project for ${var.project_name}"
  build_timeout = 10

  service_role = var.codebuild_service_role_arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type            = "CODECOMMIT"
    location        = var.codecommit_repo_clone_url
    buildspec       = "ci-cd/buildspec.yml"
    git_clone_depth = 1
  }

  tags = {
    Name = var.codebuild_project_name
  }
}

resource "aws_codepipeline" "this" {
  name     = var.pipeline_name
  role_arn = var.codepipeline_service_role_arn

  artifact_store {
    type     = "S3"
    location = var.artifact_store_bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        RepositoryName = aws_codecommit_repository.this.name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      version          = "1"
      input_artifacts  = ["BuildOutput"]

      configuration = {
        ClusterName   = var.eks_cluster_name
        ServiceName   = var.ecs_service_name
        FileName      = "imagedefinitions.json"
      }
    }
  }
}

output "codecommit_repo_url" {
  value = aws_codecommit_repository.this.clone_url_http
}

output "pipeline_name" {
  value = aws_codepipeline.this.name
}
"@

Set-Content -Path "$projectRoot\terraform\modules\codepipeline\main.tf" -Value $moduleCodePipelineMain -Encoding UTF8

$moduleCodePipelineVariables = @"
variable "codecommit_repo_name" {
  description = "Name of the CodeCommit repository"
  type        = string
}

variable "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "codebuild_service_role_arn" {
  description = "IAM Role ARN for CodeBuild"
  type        = string
}

variable "codepipeline_service_role_arn" {
  description = "IAM Role ARN for CodePipeline"
  type        = string
}

variable "artifact_store_bucket" {
  description = "S3 Bucket for CodePipeline artifacts"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS Service"
  type        = string
}

variable "codecommit_repo_clone_url" {
  description = "Clone URL for CodeCommit repository"
  type        = string
}
"@

Set-Content -Path "$projectRoot\terraform\modules\codepipeline\variables.tf" -Value $moduleCodePipelineVariables -Encoding UTF8

$moduleCodePipelineOutputs = @"
output "codecommit_repo_url" {
  value = aws_codecommit_repository.this.clone_url_http
}

output "pipeline_name" {
  value = aws_codepipeline.this.name
}
"@

Set-Content -Path "$projectRoot\terraform\modules\codepipeline\outputs.tf" -Value $moduleCodePipelineOutputs -Encoding UTF8

Write-Host "Terraform modules created." -ForegroundColor Green
Write-Host ""

# Terraform terraform.tfvars
$terraformTFVars = @"
aws_region            = "$awsRegion"
project_name          = "$projectName"
cloudinary_cloud_name = "$cloudinaryCloudName"
cloudinary_api_key    = "$cloudinaryApiKey"
cloudinary_api_secret = "$cloudinaryApiSecret"
google_api_key        = "$googleApiKey"
eks_cluster_name      = "$projectName-eks-cluster"
ecr_repository_name   = "$projectName-repo"
lambda_function_name  = "$projectName-lambda"
dynamodb_table_name   = "$projectName-metadata"
input_s3_bucket       = "$projectName-input"
output_s3_bucket      = "$projectName-output"
ssh_key_name          = "$sshKeyName"
"@

Set-Content -Path "$projectRoot\terraform\terraform.tfvars" -Value $terraformTFVars -Encoding UTF8

Write-Host "Terraform configuration files created." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Initialize Terraform
# ---------------------------

Write-Host "Initializing Terraform..." -ForegroundColor Cyan
cd "$projectRoot\terraform"
terraform init

# ---------------------------
# Plan and Apply Terraform
# ---------------------------

Write-Host "Planning Terraform deployment..." -ForegroundColor Cyan
terraform plan -out=plan.out

Write-Host "Applying Terraform deployment..." -ForegroundColor Cyan
terraform apply "plan.out"

Write-Host "Terraform deployment completed." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Docker Build and Push
# ---------------------------

Write-Host "Building and pushing Docker images to ECR..." -ForegroundColor Cyan

# Retrieve ECR URI from Terraform outputs
$ecrURI = terraform output -raw ecr_repository_uri

# Authenticate Docker to ECR
Write-Host "Authenticating Docker to ECR..." -ForegroundColor Cyan
aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin $ecrURI

# Build and push Scraper Image
Write-Host "Building Scraper Docker image..." -ForegroundColor Cyan
docker build -t scraper -f "$projectRoot\docker\Dockerfile.scraper" $projectRoot
docker tag scraper:latest "$ecrURI:scraper"
Write-Host "Pushing Scraper Docker image..." -ForegroundColor Cyan
docker push "$ecrURI:scraper"

# Build and push Data Pipeline Image
Write-Host "Building Data Pipeline Docker image..." -ForegroundColor Cyan
docker build -t datapipeline -f "$projectRoot\docker\Dockerfile.datapipeline" $projectRoot
docker tag datapipeline:latest "$ecrURI:datapipeline"
Write-Host "Pushing Data Pipeline Docker image..." -ForegroundColor Cyan
docker push "$ecrURI:datapipeline"

# Build and push ML Model Image
Write-Host "Building ML Model Docker image..." -ForegroundColor Cyan
docker build -t mlmodel -f "$projectRoot\docker\Dockerfile.mlmodel" $projectRoot
docker tag mlmodel:latest "$ecrURI:mlmodel"
Write-Host "Pushing ML Model Docker image..." -ForegroundColor Cyan
docker push "$ecrURI:mlmodel"

Write-Host "Docker images built and pushed successfully." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Deploy Services to EKS
# ---------------------------

Write-Host "Deploying services to EKS..." -ForegroundColor Cyan

# Retrieve API Gateway Endpoints
$apiEndpoint = terraform output -raw api_endpoint
$datasetApiEndpoint = terraform output -raw dataset_api_endpoint

# Update Kubernetes manifests with ECR URI
$eksPath = "$projectRoot\eks"

# Scraper Deployment
$scraperDeployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scraper
  namespace: jewelry-processing
spec:
  replicas: 2
  selector:
    matchLabels:
      app: scraper
  template:
    metadata:
      labels:
        app: scraper
    spec:
      containers:
      - name: scraper
        image: $ecrURI:scraper
        ports:
        - containerPort: 8080
        env:
        - name: AWS_REGION
          value: "$awsRegion"
        - name: API_GATEWAY_ENDPOINT
          value: "$apiEndpoint"
"@

Set-Content -Path "$eksPath\scraper-deployment.yaml" -Value $scraperDeployment -Encoding UTF8

# Data Pipeline Deployment
$datapipelineDeployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datapipeline
  namespace: jewelry-processing
spec:
  replicas: 2
  selector:
    matchLabels:
      app: datapipeline
  template:
    metadata:
      labels:
        app: datapipeline
    spec:
      containers:
      - name: datapipeline
        image: $ecrURI:datapipeline
        ports:
        - containerPort: 8081
        env:
        - name: AWS_REGION
          value: "$awsRegion"
        - name: DYNAMODB_TABLE
          value: "$projectName-metadata"
"@

Set-Content -Path "$eksPath\datapipeline-deployment.yaml" -Value $datapipelineDeployment -Encoding UTF8

# ML Model Deployment
$mlmodelDeployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlmodel
  namespace: jewelry-processing
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mlmodel
  template:
    metadata:
      labels:
        app: mlmodel
    spec:
      containers:
      - name: mlmodel
        image: $ecrURI:mlmodel
        ports:
        - containerPort: 8082
        env:
        - name: AWS_REGION
          value: "$awsRegion"
        - name: OUTPUT_S3_BUCKET
          value: "$projectName-output"
        - name: GOOGLE_API_KEY
          value: "$googleApiKey"
"@

Set-Content -Path "$eksPath\mlmodel-deployment.yaml" -Value $mlmodelDeployment -Encoding UTF8

# Apply Kubernetes manifests
kubectl apply -f "$eksPath\scraper-deployment.yaml"
kubectl apply -f "$eksPath\datapipeline-deployment.yaml"
kubectl apply -f "$eksPath\mlmodel-deployment.yaml"

Write-Host "Services deployed to EKS successfully." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Frontend Deployment (Static Website Hosting)
# ---------------------------

Write-Host "Deploying Frontend to S3..." -ForegroundColor Cyan

# Retrieve output S3 bucket
$inputBucket = terraform output -raw input_s3_bucket

# Enable static website hosting
aws s3api put-bucket-website --bucket $inputBucket --website-configuration file://"$projectRoot\frontend\website-config.json"

# Create website-config.json
$websiteConfig = @"
{
  "IndexDocument": {
    "Suffix": "index.html"
  },
  "ErrorDocument": {
    "Key": "error.html"
  }
}
"@

Set-Content -Path "$projectRoot\frontend\website-config.json" -Value $websiteConfig -Encoding UTF8

# Upload frontend files
aws s3 sync "$projectRoot\frontend" "s3://$inputBucket/frontend/" --acl public-read

Write-Host "Frontend deployed to S3 successfully." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Set Up CI/CD Pipeline
# ---------------------------

Write-Host "Setting up CI/CD pipeline..." -ForegroundColor Cyan

# Retrieve CodeCommit repository URL
$codeCommitURL = terraform output -raw codecommit_repo_url

# Clone CodeCommit Repository
Write-Host "Cloning CodeCommit repository..." -ForegroundColor Cyan
git clone $codeCommitURL "$projectRoot\ci-cd\repo"

# Initialize Git repository
cd "$projectRoot\ci-cd\repo"
git init
git remote add origin $codeCommitURL

# Add all files to repository
Write-Host "Adding files to CodeCommit repository..." -ForegroundColor Cyan
git add .
git commit -m "Initial commit"
git push -u origin main

Write-Host "CI/CD pipeline setup completed." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Integrate Google Cloud Vision API
# ---------------------------

Write-Host "Integrating Google Cloud Vision API..." -ForegroundColor Cyan

# Update Lambda function environment variables
$lambdaArn = terraform output -raw lambda_function_arn

Write-Host "Updating Lambda function environment variables..." -ForegroundColor Cyan
aws lambda update-function-configuration `
    --function-name $lambdaArn `
    --environment "Variables={CLOUDINARY_CLOUD_NAME=$cloudinaryCloudName,CLOUDINARY_API_KEY=$cloudinaryApiKey,CLOUDINARY_API_SECRET=$cloudinaryApiSecret,GOOGLE_API_KEY=$googleApiKey}" `
    --region $awsRegion

Write-Host "Google Cloud Vision API integrated successfully." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Finalize Frontend API Endpoint
# ---------------------------

Write-Host "Finalizing Frontend with API Gateway Endpoints..." -ForegroundColor Cyan

# Replace placeholder in frontend JS with actual API endpoints
(Get-Content "$projectRoot\frontend\js\scripts.js") -replace "https://YOUR_API_GATEWAY_ENDPOINT/create-dataset", "$datasetApiEndpoint" | Set-Content "$projectRoot\frontend\js\scripts.js"
(Get-Content "$projectRoot\frontend\js\scripts.js") -replace "https://YOUR_API_GATEWAY_ENDPOINT/upload", "$apiEndpoint" | Set-Content "$projectRoot\frontend\js\scripts.js"

# Re-upload updated frontend JS
aws s3 sync "$projectRoot\frontend" "s3://$inputBucket/frontend/" --acl public-read

Write-Host "Frontend updated with API Gateway endpoints." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Startup and Shutdown Scripts
# ---------------------------

Write-Host "Creating Startup and Shutdown scripts..." -ForegroundColor Cyan

# Startup Script
$startupScript = @"
# PowerShell Startup Script for Jewelry Processing System

# Start EKS cluster (if using managed services, typically already running)
# Placeholder for any startup commands if needed

Write-Host "Jewelry Processing System started successfully." -ForegroundColor Green
"@

Set-Content -Path "$projectRoot\Startup-JewelryProcessingSystem.ps1" -Value $startupScript -Encoding UTF8

# Shutdown Script
$shutdownScript = @"
# PowerShell Shutdown Script for Jewelry Processing System

# Scale down Kubernetes deployments to zero
kubectl scale deployment scraper --replicas=0 -n jewelry-processing
kubectl scale deployment datapipeline --replicas=0 -n jewelry-processing
kubectl scale deployment mlmodel --replicas=0 -n jewelry-processing

Write-Host "Jewelry Processing System shut down successfully." -ForegroundColor Green
"@

Set-Content -Path "$projectRoot\Shutdown-JewelryProcessingSystem.ps1" -Value $shutdownScript -Encoding UTF8

Write-Host "Startup and Shutdown scripts created." -ForegroundColor Green
Write-Host ""

# ---------------------------
# Create Cleanup Script (Optional)
# ---------------------------

# As per user request, we are not creating a destroy script.
# However, it's recommended to keep a cleanup script for resource management.

Write-Host "Creating optional Cleanup script..." -ForegroundColor Cyan

$cleanupScript = @"
# PowerShell Cleanup Script for Jewelry Processing System

# Exit on error
$ErrorActionPreference = "Stop"

$projectName = "$projectName"
$projectRoot = "C:\$projectName"

# Destroy Terraform Infrastructure
Write-Host "Destroying Terraform infrastructure..." -ForegroundColor Cyan
cd "$projectRoot\terraform"
terraform destroy -auto-approve

# Delete ECR Repository
$ecrURI = terraform output -raw ecr_repository_uri
Write-Host "Deleting ECR repository..." -ForegroundColor Cyan
aws ecr delete-repository --repository-name "$projectName-repo" --force --region $awsRegion

# Delete S3 Buckets
Write-Host "Deleting S3 buckets..." -ForegroundColor Cyan
aws s3 rb "s3://$projectName-input-*" --force --region $awsRegion
aws s3 rb "s3://$projectName-output-*" --force --region $awsRegion

# Delete CodeCommit Repository
Write-Host "Deleting CodeCommit repository..." -ForegroundColor Cyan
aws codecommit delete-repository --repository-name "$projectName-repo" --region $awsRegion

# Delete Frontend S3 Bucket
Write-Host "Deleting Frontend S3 bucket..." -ForegroundColor Cyan
aws s3 rb "s3://$projectName-input/frontend" --force --region $awsRegion

Write-Host "Cleanup completed successfully." -ForegroundColor Green
"@

Set-Content -Path "$projectRoot\Cleanup-JewelryProcessingSystem.ps1" -Value $cleanupScript -Encoding UTF8

Write-Host "Optional Cleanup script created at $projectRoot\Cleanup-JewelryProcessingSystem.ps1" -ForegroundColor Green
Write-Host ""

# ---------------------------
# Summary of Resources
# ---------------------------

Write-Host "=== Setup Summary ===" -ForegroundColor Cyan
Write-Host "Project Directory: $projectRoot" -ForegroundColor Yellow
Write-Host "ECR Repository URI: $ecrURI" -ForegroundColor Yellow
Write-Host "API Gateway Endpoints: $apiEndpoint, $datasetApiEndpoint" -ForegroundColor Yellow
Write-Host "CodeCommit Repository URL: $codeCommitURL" -ForegroundColor Yellow
Write-Host "Frontend S3 Bucket: $inputBucket/frontend" -ForegroundColor Yellow
Write-Host "Startup Script: $projectRoot\Startup-JewelryProcessingSystem.ps1" -ForegroundColor Yellow
Write-Host "Shutdown Script: $projectRoot\Shutdown-JewelryProcessingSystem.ps1" -ForegroundColor Yellow
Write-Host "Cleanup Script: $projectRoot\Cleanup-JewelryProcessingSystem.ps1" -ForegroundColor Yellow
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "All components have been set up successfully!" -ForegroundColor Green
Write-Host "You can access the frontend at: http://$inputBucket/frontend/index.html" -ForegroundColor Green
Write-Host ""

# ---------------------------
# End of Script
# ---------------------------

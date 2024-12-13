## [ To process a folder of images ]

dataset_manager = JewelryDatasetManager({
    'aws_bucket': 'your-bucket-name',
    'min_image_size': 512
})

# Process all folders
asyncio.run(dataset_manager.process_local_folders('raw_data'))


## [ To scrape websites for data ]

scraper = JewelryWebScraper({
    'target_sites': [
        {
            'url': 'https://your-jewelry-site.com',
            'selectors': {
                'image': 'div.product-image img',
                'title': 'h1.product-title',
                'price': 'span.price'
            }
        }
    ]
})

# Start scraping
asyncio.run(scraper.start_scraping())


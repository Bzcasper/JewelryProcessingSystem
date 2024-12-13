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

Apply the Secret:

kubectl apply -f kubernetes/secrets/aws-credentials.yaml

kubectl apply -f kubernetes/secrets/aws-credentials.yaml
b. Apply PersistentVolumeClaims
kubectl apply -f kubernetes/persistent-volume-claims/
c. Apply Deployments
kubectl apply -f kubernetes/deployments/
d. Apply Services
kubectl apply -f kubernetes/services/
e. Apply Ingress
kubectl apply -f kubernetes/ingress/
f. Verify Resources
Check Pods:

kubectl get pods
Check PVCs:

kubectl get pvc
Check Services:

kubectl get services
Check Ingress:

kubectl get ingress



![alt text](image.png)

![alt text](image-1.png)


Access key
If you lose or forget your secret access key, you cannot retrieve it. Instead, create a new access key and make the old key inactive.

Access key
Secret access key

AKIASVLKCEFPRDJOE2WJ

nX22PFy3r7l+tAvO6FnpHqi11+4/1FZSEkDIYJyj

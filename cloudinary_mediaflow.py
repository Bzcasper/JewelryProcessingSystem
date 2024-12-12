from cloudinary import CloudinaryImage
from cloudinary.uploader import upload
from cloudinary.utils import cloudinary_url
import cloudinary.api
import os

class JewelryMediaPipeline:
    def __init__(self, cloud_name, api_key, api_secret):
        """Initialize Cloudinary configuration"""
        cloudinary.config(
            cloud_name=cloud_name,
            api_key=api_key,
            api_secret=api_secret
        )
        
        # Define transformation presets
        self.presets = {
            'thumbnail': [
                {'width': 300, 'height': 300, 'crop': 'fill'},
                {'quality': 'auto:best'},
                {'fetch_format': 'auto'}
            ],
            'detail': [
                {'width': 800, 'height': 800, 'crop': 'fill'},
                {'quality': 'auto:best'},
                {'fetch_format': 'auto'},
                {'effect': 'sharpen:100'}
            ],
            'zoom': [
                {'width': 1200, 'height': 1200, 'crop': 'fill'},
                {'quality': 'auto:best'},
                {'fetch_format': 'auto'},
                {'effect': 'sharpen:200'}
            ],
            '360': [
                {'width': 600, 'height': 600, 'crop': 'fill'},
                {'quality': 'auto:best'},
                {'format': 'gif'},
                {'effect': 'loop'}
            ]
        }
        
    def upload_jewelry_image(self, image_path, category, style):
        """Upload jewelry image with automatic transformations"""
        try:
            # Upload with eager transformations
            response = upload(
                image_path,
                folder=f"jewelry/{category}/{style}",
                resource_type="image",
                eager=[
                    self._get_transformation('thumbnail'),
                    self._get_transformation('detail'),
                    self._get_transformation('zoom')
                ],
                eager_async=True,
                tags=[category, style, "jewelry"],
                # Set auto background removal for white background
                background_removal="white",
                # Enable automatic quality and format optimization
                quality_analysis=True,
                # Add artistic filters for different views
                transformation=[
                    {'effect': 'art:athena'}, # Enhances jewelry details
                    {'color': 'vibrancy:50'}, # Boost colors
                    {'effect': 'brightness:10'} # Slight brightness increase
                ]
            )
            
            return {
                'public_id': response['public_id'],
                'urls': {
                    'thumbnail': self.get_url(response['public_id'], 'thumbnail'),
                    'detail': self.get_url(response['public_id'], 'detail'),
                    'zoom': self.get_url(response['public_id'], 'zoom')
                },
                'metadata': response['metadata']
            }
            
        except Exception as e:
            print(f"Error uploading image: {str(e)}")
            return None
            
    def create_360_view(self, image_paths, category, style):
        """Create 360-degree view from multiple images"""
        try:
            # Upload all images
            uploads = []
            for path in image_paths:
                response = upload(
                    path,
                    folder=f"jewelry/{category}/{style}/360",
                    resource_type="image"
                )
                uploads.append(response['public_id'])
            
            # Create multi-image transformation
            transformation = {
                'transformation': [
                    {'width': 600, 'height': 600, 'crop': 'fill'},
                    {'quality': 'auto:best'}
                ],
                'effect': 'loop',
                'format': 'gif'
            }
            
            # Generate 360 view
            response = cloudinary.api.create_slideshow(
                uploads,
                transformation=transformation,
                notification_url="your-callback-url"
            )
            
            return {
                'public_id': response['public_id'],
                'url': self.get_url(response['public_id'], '360')
            }
            
        except Exception as e:
            print(f"Error creating 360 view: {str(e)}")
            return None
            
    def _get_transformation(self, preset):
        """Get transformation settings for a preset"""
        if preset not in self.presets:
            raise ValueError(f"Unknown preset: {preset}")
        return self.presets[preset]
        
    def get_url(self, public_id, preset):
        """Get URL for an image with specific preset"""
        url, options = cloudinary_url(
            public_id,
            transformation=self._get_transformation(preset)
        )
        return url

    def optimize_existing_images(self, folder):
        """Optimize all existing images in a folder"""
        try:
            # Get all images in folder
            resources = cloudinary.api.resources(
                type="upload",
                prefix=folder,
                max_results=500
            )
            
            # Apply optimizations to each image
            for resource in resources['resources']:
                cloudinary.api.update(
                    resource['public_id'],
                    quality_analysis=True,
                    auto_tagging=0.6,
                    categorization="aws_rek_tagging"
                )
                
            return True
            
        except Exception as e:
            print(f"Error optimizing images: {str(e)}")
            return False

    def create_watermark(self, text):
        """Create a watermark overlay"""
        try:
            response = cloudinary.uploader.text(
                text,
                font_family="Arial",
                font_size=14,
                opacity=50
            )
            
            return response['public_id']
            
        except Exception as e:
            print(f"Error creating watermark: {str(e)}")
            return None

# Usage example
if __name__ == "__main__":
    pipeline = JewelryMediaPipeline(
        cloud_name="your_cloud_name",
        api_key="your_api_key",
        api_secret="your_api_secret"
    )
    
    # Upload single image
    result = pipeline.upload_jewelry_image(
        "ring.jpg", 
        category="rings",
        style="vintage"
    )
    
    # Create 360 view
    images = ["ring_1.jpg", "ring_2.jpg", "ring_3.jpg", "ring_4.jpg"]
    view_360 = pipeline.create_360_view(
        images,
        category="rings",
        style="vintage"
    )
    
    # Create watermark
    watermark = pipeline.create_watermark("© Your Jewelry Store")
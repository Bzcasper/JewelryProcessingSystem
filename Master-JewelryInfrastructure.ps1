# Master-JewelryInfrastructure.ps1

param (
    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot = "C:\JewelryProcessingSystem",
    
    [Parameter(Mandatory=$false)]
    [string]$AwsRegion = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipOptimization
)

# Error handling and logging setup
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$logFile = "deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Level : $Message"
    
    # Write to console
    $color = switch($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    Write-Host $logMessage -ForegroundColor $color
    
    # Write to log file
    Add-Content -Path $logFile -Value $logMessage
}

function Test-Prerequisites {
    $required = @(
        @{Name = "AWS CLI"; Command = "aws --version"},
        @{Name = "Terraform"; Command = "terraform --version"},
        @{Name = "Docker"; Command = "docker --version"},
        @{Name = "Python"; Command = "python --version"},
        @{Name = "Git"; Command = "git --version"},
        @{Name = "kubectl"; Command = "kubectl version --client"}
    )
    
    $missing = @()
    foreach ($tool in $required) {
        try {
            Invoke-Expression $tool.Command | Out-Null
            Write-Log "$($tool.Name) found"
        }
        catch {
            $missing += $tool.Name
            Write-Log "$($tool.Name) not found" -Level 'Error'
        }
    }
    
    if ($missing.Count -gt 0) {
        throw "Missing prerequisites: $($missing -join ', ')"
    }
}

function Initialize-Project {
    # Get credentials
    $cloudinaryCloudName = Read-Host "Enter Cloudinary Cloud Name"
    $cloudinaryApiKey = Read-Host "Enter Cloudinary API Key"
    $cloudinaryApiSecret = Read-Host "Enter Cloudinary API Secret" -AsSecureString
    $googleApiKey = Read-Host "Enter Google Cloud Vision API Key" -AsSecureString
    
    # Create secure parameter file
    $params = @{
        CloudinaryCloudName = $cloudinaryCloudName
        CloudinaryApiKey = $cloudinaryApiKey
        CloudinaryApiSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($cloudinaryApiSecret))
        GoogleApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($googleApiKey))
    }
    
    $params | ConvertTo-Json | Set-Content "$ProjectRoot\secure-params.json"
    Write-Log "Secure parameters saved"
    
    return $params
}

function Start-Infrastructure {
    param($Params)
    
    # Run infrastructure setup script
    try {
        Write-Log "Starting infrastructure deployment..."
        
        # Source the setup script with parameters
        . "$PSScriptRoot\setup-aws-infrastructure.ps1" `
            -ProjectRoot $ProjectRoot `
            -AwsRegion $AwsRegion `
            -CloudinaryCloudName $Params.CloudinaryCloudName `
            -CloudinaryApiKey $Params.CloudinaryApiKey `
            -CloudinaryApiSecret $Params.CloudinaryApiSecret `
            -GoogleApiKey $Params.GoogleApiKey
            
        Write-Log "Infrastructure deployment completed"
    }
    catch {
        Write-Log "Infrastructure deployment failed: $_" -Level 'Error'
        throw
    }
}

function Start-Optimization {
    try {
        Write-Log "Starting code optimization..."
        
        # Source the optimization script
        . "$PSScriptRoot\Optimize-Infrastructure.ps1" `
            -ProjectRoot $ProjectRoot
            
        Write-Log "Code optimization completed"
    }
    catch {
        Write-Log "Code optimization failed: $_" -Level 'Error'
        throw
    }
}

function Test-Deployment {
    try {
        Write-Log "Testing deployment..."
        
        # Test API endpoints
        $apiEndpoint = terraform output -raw api_endpoint
        $response = Invoke-RestMethod -Uri "$apiEndpoint/health" -Method Get
        if ($response.status -ne "healthy") {
            throw "API health check failed"
        }
        
        # Test Kubernetes deployments
        $deployments = kubectl get deployments -n jewelry-processing -o json | ConvertFrom-Json
        foreach ($deployment in $deployments.items) {
            if ($deployment.status.readyReplicas -lt $deployment.spec.replicas) {
                throw "Deployment $($deployment.metadata.name) not ready"
            }
        }
        
        Write-Log "All deployment tests passed"
        return $true
    }
    catch {
        Write-Log "Deployment tests failed: $_" -Level 'Error'
        return $false
    }
}

# Main execution
try {
    Write-Log "Starting master deployment script..."
    
    # Check prerequisites
    Test-Prerequisites
    
    # Initialize project and get parameters
    $params = Initialize-Project
    
    # Deploy infrastructure
    Start-Infrastructure -Params $params
    
    # Run optimization unless skipped
    if (-not $SkipOptimization) {
        Start-Optimization
    }
    
    # Test deployment
    if (Test-Deployment) {
        Write-Log "Deployment completed successfully!"
        
        # Output important information
        Write-Log "=== Deployment Summary ===" -Level 'Info'
        Write-Log "Project Directory: $ProjectRoot"
        Write-Log "API Endpoint: $(terraform output -raw api_endpoint)"
        Write-Log "Frontend URL: http://$(terraform output -raw input_s3_bucket)/frontend/index.html"
        Write-Log "Log File: $logFile"
    }
    else {
        throw "Deployment validation failed"
    }
}
catch {
    Write-Log "Master deployment failed: $_" -Level 'Error'
    Write-Log "Check $logFile for detailed logs"
    exit 1
}
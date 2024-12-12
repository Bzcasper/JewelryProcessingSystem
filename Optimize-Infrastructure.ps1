# PowerShell Script: Code Cleanup and Production Preparation
param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    
    Write-Host "[$timestamp] $Level : $Message" -ForegroundColor $color
}

function Test-PythonSyntax {
    param(
        [string]$FilePath
    )
    
    try {
        $result = python -m py_compile $FilePath 2>&1
        return $true
    }
    catch {
        Write-Log "Python syntax error in $FilePath : $_" -Level 'Error'
        return $false
    }
}

function Format-PythonCode {
    param(
        [string]$FilePath
    )
    
    try {
        # Install black if not present
        if (!(Get-Command black -ErrorAction SilentlyContinue)) {
            pip install black
        }
        
        black $FilePath
        Write-Log "Formatted $FilePath"
    }
    catch {
        Write-Log "Failed to format $FilePath : $_" -Level 'Error'
    }
}

function Optimize-TerraformCode {
    param(
        [string]$TerraformDir
    )
    
    try {
        Set-Location $TerraformDir
        
        # Format Terraform code
        terraform fmt -recursive
        
        # Validate Terraform code
        terraform validate
        
        Write-Log "Terraform code optimized and validated in $TerraformDir"
    }
    catch {
        Write-Log "Failed to optimize Terraform code: $_" -Level 'Error'
    }
}

function Update-DockerfileOptimizations {
    param(
        [string]$DockerfilePath
    )
    
    try {
        $content = Get-Content $DockerfilePath -Raw
        
        # Add production optimizations
        $optimizedContent = $content -replace 
            "FROM python:3.9-slim", 
            "FROM python:3.9-slim-bullseye as builder`n`nENV PYTHONUNBUFFERED=1`nENV PIP_NO_CACHE_DIR=1"
        
        # Add multi-stage build
        $optimizedContent += "`n`nFROM python:3.9-slim-bullseye as runtime`n`nCOPY --from=builder /usr/local/lib/python3.9/site-packages/ /usr/local/lib/python3.9/site-packages/`n"
        
        Set-Content $DockerfilePath $optimizedContent
        Write-Log "Optimized Dockerfile at $DockerfilePath"
    }
    catch {
        Write-Log "Failed to optimize Dockerfile: $_" -Level 'Error'
    }
}

function Add-SecurityHeaders {
    param(
        [string]$ApiGatewayPath
    )
    
    try {
        $content = Get-Content $ApiGatewayPath -Raw
        
        # Add security headers
        $securityHeaders = @"
  response_headers = {
    "X-Frame-Options" = "DENY"
    "X-Content-Type-Options" = "nosniff"
    "X-XSS-Protection" = "1; mode=block"
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains"
    "Content-Security-Policy" = "default-src 'self'"
  }
"@
        
        $content = $content -replace "(?s)(resource.*?\{.*?\})", "`$1`n  $securityHeaders"
        Set-Content $ApiGatewayPath $content
        
        Write-Log "Added security headers to API Gateway configuration"
    }
    catch {
        Write-Log "Failed to add security headers: $_" -Level 'Error'
    }
}

function Update-Configurations {
    param(
        [string]$ProjectRoot
    )
    
    try {
        # Update Python requirements
        Get-ChildItem -Path $ProjectRoot -Filter "requirements*.txt" -Recurse | ForEach-Object {
            $content = Get-Content $_.FullName
            $content = $content | ForEach-Object { 
                if ($_ -match '^([^=]+)==') {
                    "$($matches[1])>=`$version"
                } else {
                    $_
                }
            }
            Set-Content $_.FullName $content
        }
        
        # Update Terraform versions
        Get-ChildItem -Path $ProjectRoot -Filter "*.tf" -Recurse | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            $content = $content -replace 'version\s*=\s*"[^"]+"', 'version = "latest"'
            Set-Content $_.FullName $content
        }
        
        Write-Log "Updated version configurations"
    }
    catch {
        Write-Log "Failed to update configurations: $_" -Level 'Error'
    }
}

function Add-MonitoringAndLogging {
    param(
        [string]$ProjectRoot
    )
    
    try {
        # Add CloudWatch configuration
        $cloudwatchConfig = @"
resource "aws_cloudwatch_log_group" "jewelry_processing" {
  name              = "/aws/jewelry-processing"
  retention_in_days = 30
  
  tags = {
    Environment = "production"
    Application = "jewelry-processing"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "jewelry-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
"@
        
        Add-Content -Path "$ProjectRoot/terraform/modules/monitoring/main.tf" -Value $cloudwatchConfig
        Write-Log "Added monitoring configuration"
    }
    catch {
        Write-Log "Failed to add monitoring configuration: $_" -Level 'Error'
    }
}

# Main execution
try {
    Write-Log "Starting code cleanup and optimization..."
    
    # Verify project structure
    if (!(Test-Path $ProjectRoot)) {
        throw "Project root directory not found: $ProjectRoot"
    }
    
    # Clean and optimize Python code
    Get-ChildItem -Path $ProjectRoot -Filter "*.py" -Recurse | ForEach-Object {
        if (Test-PythonSyntax $_.FullName) {
            Format-PythonCode $_.FullName
        }
    }
    
    # Optimize Terraform code
    Optimize-TerraformCode "$ProjectRoot\terraform"
    
    # Update Dockerfiles
    Get-ChildItem -Path "$ProjectRoot\docker" -Filter "Dockerfile*" | ForEach-Object {
        Update-DockerfileOptimizations $_.FullName
    }
    
    # Add security headers to API Gateway
    Add-SecurityHeaders "$ProjectRoot\terraform\modules\api_gateway\main.tf"
    
    # Update configurations
    Update-Configurations $ProjectRoot
    
    # Add monitoring and logging
    Add-MonitoringAndLogging $ProjectRoot
    
    Write-Log "Code cleanup and optimization completed successfully!"
}
catch {
    Write-Log "Failed to complete cleanup: $_" -Level 'Error'
    exit 1
}
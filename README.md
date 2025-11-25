# Dockerfile best practices
Best practices and examples for writing optimized, secure, and production-ready Dockerfiles.

This repository demonstrates the process of improving a basic Dockerfile used to run an Apache HTTP server. The project highlights the evolution from an outdated, suboptimal Dockerfile to a modern, secure, and efficient version that adheres to container best practices.

It includes:
  
- The original Dockerfile for reference
- The optimized Dockerfile
- A technical deep-dive into every improvement applied
- A minimal example of static website content

## 📁 Repository Structure

dockerfile-improvements/

├── Dockerfile # Optimized version

├── Dockerfile.original # Original version for comparison

├── src/ # Static HTML/CSS/JS served by Apache

├── .dockerignore

└── README.md

## Useful commands:

Build the Image : docker build -t apache-optimized 

Run the Container: docker run -p 8080:80 apache-optimized
Access in your browser: http://localhost:8080

# Technical Deep Dive — Why These Improvements Matter:

This section explains each improvement applied to the Dockerfile and the underlying rationale based on container engineering principles.

##  1 - Updating Ubuntu 

  Ubuntu 18.04 is End-of-Life (EOL). It no longer receives security updates, which exposes the container to vulnerabilities. 
  An outdated base image becomes a liability even if new packages are installed on top.
  So it is important to update 18.04 to recent stable release, in this case Ubuntu 22.04 .

## 2 - Combining apt-get update and apt-get install in the same layer

Original approach

```
RUN apt-get update
RUN apt-get install -y apache2
```

 Improved approach
 
```
RUN apt-get update \
&& apt-get install -y apache2 \
&& rm -rf /var/lib/apt/lists/*
```

Original approach can causes real issues:

### 2.1 - Non-deterministic builds and Cache instability

**Non-deterministic builds** : apt-get update caches metadata until that layer is invalidated. Old metadata can cause installs to break or pull different package versions.

**Cache instability** : the update layer may persist stale package indexes, meaning two developers building the “same” Dockerfile may produce different binary versions.

### 2.2 -  Larger images and wasted space

In the original Dockerfile, no cleanup of APT metadata is performed. The apt-get update command creates files in /var/lib/apt/lists/ in the first layer, and apt-get install adds another layer.

As a result, the image carries all the package index files, leading to:
- Unnecessarily larger image sizes, increasing build, pull, and deploy times.
- Higher storage and network usage, especially in CI/CD pipelines or when scaling containers.
- Less reproducible builds due to retained stale metadata in intermediate layers.

The improved approach combines apt-get update, apt-get install, and rm -rf /var/lib/apt/lists/* in a single RUN instruction, ensuring cleanup happens in the same layer and producing a smaller, cleaner, and reproducible image.

### 2.3 – Negative impact on CI/CD and pipelines with aggressive caching

In CI/CD systems (GitHub Actions, GitLab Runner, Jenkins), the Docker layer cache is used to speed up builds.

When apt-get update is executed in a separate layer, pipelines may start building with outdated package indexes. A build might work one day but fail the next, and different developers could get different results. This often forces the use of manual cache busting — forcing Docker to ignore cached layers and rebuild them — which is undesirable because it slows down builds, increases network usage, and can lead to inconsistent or non-reproducible images.

All of this is avoided when update + install are placed in the same RUN instruction.

Alternativly to avoid such effects, some bad Devs add hacks such as:
```
RUN apt-get update || true
```
or 
```
RUN apt-get update --allow-releaseinfo-change
```
Important Note: These approaches are not recommended because they hide real issues, can lead to non-deterministic builds, install outdated or inconsistent packages, and increase security risks. The proper practice is to combine apt-get update and apt-get install in the same layer, ensuring reproducible and secure builds.

## 3 -  Absolute path vs. PATH lookup

Original version uses the full filesystem path:

```CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]```

Improved version relies on the binary being found in the image’s $PATH:

```CMD ["apache2ctl", "-D", "FOREGROUND"]```

### 3.1 - Portability across distributions

Even though most Debian/Ubuntu images store ```apache2ctl``` in ```/usr/sbin```, this location is not guaranteed across custom distroless images, minimal images, or images with altered $PATH or different FHS layouts.
By using ```apache2ctl``` without a hard-coded path, Docker relies on the runtime $PATH (typically ```/usr/sbin```, ```/usr/bin```, ```/sbin```, and ```/bin```), making the Dockerfile more resilient and portable across different environments.

It is also more maintainable, becasue if the binary ever moves (e.g., packaging changes), only the $PATH needs to be adapted, whereas hard-coded paths require modifying the Dockerfile.
Additionally, this is the cleaner and recommended style, as Docker best practices suggest letting the image’s $PATH resolve binaries unless they are in unusual locations.


### 3.2 - Down side of the PATH lookup approach:

If the PATH is misconfigured or restricted (common in hardened / distroless images), Docker may fail to locate the binary.
But for Ubuntu-based images like this one, PATH already includes /usr/sbin, so the shorter version is completely safe and more maintainable.



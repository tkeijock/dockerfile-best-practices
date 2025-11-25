# dockerfile-best-practices
Best practices and examples for writing optimized, secure, and production-ready Dockerfiles.

This repository demonstrates the process of improving a basic Dockerfile used to run an Apache HTTP server. The project highlights the evolution from an outdated, suboptimal Dockerfile to a modern, secure, and efficient version that adheres to container best practices.

It includes:
  
- The original Dockerfile for reference
- The optimized Dockerfile
- A technical deep-dive into every improvement applied
- A minimal example of static website content

# 📁 Repository Structure

dockerfile-improvements/

├── Dockerfile # Optimized version

├── Dockerfile.original # Original version for comparison

├── src/ # Static HTML/CSS/JS served by Apache

├── .dockerignore

└── README.md

# Useful commands:

Build the Image : docker build -t apache-optimized 

Run the Container: docker run -p 8080:80 apache-optimized
Access in your browser: http://localhost:8080


# Technical Deep Dive — Why These Improvements Matter:

This section explains each improvement applied to the Dockerfile and the underlying rationale based on container engineering principles.

1. Updating Ubuntu 18.04 to Ubuntu 22.04

1.1 Ubuntu 18.04 is End-of-Life (EOL). It no longer receives security updates, which exposes the container to vulnerabilities. 
An outdated base image becomes a liability even if new packages are installed on top.

2. Combining apt-get update and apt-get install in the same layer
 Original approach
RUN apt-get update
RUN apt-get install -y apache2

 Improved approach
RUN apt-get update \
 && apt-get install -y apache2 \
 && rm -rf /var/lib/apt/lists/*

Original approach can causes real issues:
2.1 Non-deterministic builds and Cache instability
Non-deterministic builds: apt-get update caches metadata until that layer is invalidated. Old metadata can cause installs to break or pull different package versions.
Cache instability: the update layer may persist stale package indexes, meaning two developers building the “same” Dockerfile may produce different binary versions.

2.2 Larger images and wasted space
Even though cleanup is present, it does not reduce the final image size because:
The APT metadata generated during apt-get update was already written to a previous immutable layer.
Deleting /var/lib/apt/lists/* in a later layer only hides the files in the top layer; it does not remove them from the underlying layers.
As a result, the image still carries the stale package indexes, leading to:

2.3 – Negative impact on CI/CD and pipelines with aggressive caching

In CI/CD systems (GitHub Actions, GitLab Runner, Jenkins), the Docker layer cache is used to speed up builds.

When apt-get update lives in a separate layer:
pipelines start building with outdated package indexes a build works one day but fails the next different developers get different results the pipeline requires manual cache busting (bad)
This effect leads companies to add hacks such as:

RUN apt-get update || true

or 

RUN apt-get update --allow-releaseinfo-change

All of this is avoided when update + install are placed in the same RUN instruction.

3 Absolute path vs. PATH lookup

Original version uses the full filesystem path:
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

Improved version relies on the binary being found in the image’s $PATH:
CMD ["apache2ctl", "-D", "FOREGROUND"]

Portability across distributions
Even though most Debian/Ubuntu images store apache2ctl in /usr/sbin, this is not guaranteed across:

custom distroless images
minimal images
images with altered PATH or different FHS layouts

When using "apache2ctl" without a hard-coded path, Docker uses the runtime PATH (typically /usr/sbin:/usr/bin:/sbin:/bin), making the Dockerfile more resilient across environments.

More maintainable If the binary ever moves (e.g., packaging changes), only the PATH needs to be adapted.
Hard-coded paths require modifying the Dockerfile.

Cleaner and recommended style Docker best practices state that unless a binary is in an unusual location, letting the image’s PATH resolve it is preferable

3.2 Down side of the improved approach:

If the PATH is misconfigured or restricted (common in hardened / distroless images), Docker may fail to locate the binary.
But for Ubuntu-based images like this one, PATH already includes /usr/sbin, so the shorter version is completely safe and more maintainable.



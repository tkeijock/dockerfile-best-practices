FROM ubuntu:22.04

# Installing apache + cleaning cache in the same RUN

RUN apt-get update \
    && apt-get install -y apache2 \
    && rm -rf /var/lib/apt/lists/*

COPY src/ /var/www/html/

EXPOSE 80

# path lookup 
CMD ["apache2ctl", "-D", "FOREGROUND"]

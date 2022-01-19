FROM ubuntu:18.04 AS base

ENV DEBIAN_FRONTEND noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install apt packages
RUN apt-get update \
    && apt-get install -y nginx curl zip unzip git software-properties-common supervisor sqlite3 vim wget locales git \
    && add-apt-repository -y ppa:ondrej/php

ENV LANG en_AU.UTF-8
ENV LANGUAGE en_AU:en
ENV LC_ALL en_AU.UTF-8
RUN sed -i '/en_AU.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - 
RUN echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list 
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install -y --no-install-recommends git libsodium-dev unzip zlib1g-dev google-chrome-stable nodejs yarn \
    build-essential \ 
    libxpm4 libxrender1 libgtk2.0-0 libnss3 libgconf-2-4 xvfb gtk2-engines-pixbuf xfonts-cyrillic \
    xfonts-100dpi xfonts-75dpi xfonts-base xfonts-scalable imagemagick x11-apps libicu-dev libzip-dev \
    php7.4-fpm php7.4-soap php7.4-cli php-pear php7.4-gd php7.4-mysql php7.4-memcached php7.4-mbstring php7.4-xml php7.4-xdebug php7.4-curl \
    php7.4-zip php7.4-memcached php7.4-dev php7.4-bcmath php7.4-gmp php7.4-imagick php7.4-sqlite3 poppler-utils mysql-client \
    && apt-get remove -y --purge software-properties-common \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN ln -fs /usr/share/zoneinfo/Australia/Brisbane /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
RUN composer global require "squizlabs/php_codesniffer=*" && composer global require staabm/annotate-pull-request-from-checkstyle
ENV PATH="$PATH:$HOME/.composer/vendor/bin"

# Nginx
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY config/default /etc/nginx/sites-available/default
COPY config/php-fpm.conf /etc/php/7.4/fpm/php-fpm.conf

EXPOSE 80

COPY config/app-supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN Xvfb -ac :0 -screen 0 1280x1024x16 &

CMD ["/usr/bin/supervisord"]

FROM base AS mssql

RUN apt update -y  &&  apt upgrade -y && apt-get update 
RUN apt install -y curl python3.7 git python3-pip openjdk-8-jdk unixodbc-dev

# Add SQL Server ODBC Driver 17 for Ubuntu 18.04
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y --allow-unauthenticated msodbcsql17
RUN ACCEPT_EULA=Y apt-get install -y --allow-unauthenticated mssql-tools
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN pecl install sqlsrv pdo_sqlsrv
RUN printf "priority=20\nextension=sqlsrv.so\n" > /etc/php/7.4/mods-available/sqlsrv.ini
RUN printf "priority=30\nextension=pdo_sqlsrv.so\n" > /etc/php/7.4/mods-available/pdo_sqlsrv.ini
RUN phpenmod sqlsrv && phpenmod pdo_sqlsrv

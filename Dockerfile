FROM openjdk:8-jdk

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Setup node repo
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -

# General update packages
#RUN sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
RUN apt-get update -y
RUN apt-get upgrade -y

# Install build tools
RUN apt-get install -y \
                     wget \
                     unzip \
                     build-essential \
		     nodejs

# Add MySQL configuration
COPY mysql.cnf /etc/mysql/conf.d/mysql.cnf
COPY mysqld_charset.cnf /etc/mysql/conf.d/mysqld_charset.cnf

#install and configure mysql
RUN apt-get -yq install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes mariadb-server-10.3 && \
    # rm /etc/mysql/conf.d/mysqld_safe_syslog.cnf && \
    if [ ! -f /usr/share/mysql/my-default.cnf ] ; then cp /etc/mysql/conf.d/mysql.cnf /usr/share/mysql/my-default.cnf; fi && \
    mysql_install_db > /dev/null 2>&1

RUN npm install http-server -g

# Create mount point
WORKDIR /build
# Add default appliction structure and deployment script
COPY build/ ./
COPY opt/ /opt

RUN chmod +x /opt/cae/deployment.sh

#Environment variables for the deployment script
# Mysql options
ENV MYSQL_USER cae-user
ENV MYSQL_PASS cae-user-1234
ENV ON_CREATE_DB caeschema

ENV MICROSERVICE_WEBCONNECTOR_PORT 8086
ENV MICROSERVICE_PORT 8087
ENV HTTP_PORT 8088

CMD "/opt/cae/deployment.sh"

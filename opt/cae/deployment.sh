#!/bin/bash

ENV_VARIABLE_NOT_SET=false
check_if_exists () {
    if [[ -z "$1" ]]; then
        echo "$2 env variable is not set"
        ENV_VARIABLE_NOT_SET=true
    fi
}

check_if_exists "$JENKINS_URL" JENKINS_URL
check_if_exists "$BUILD_JOB_NAME" BUILD_JOB_NAME
check_if_exists "$DOCKER_URL" DOCKER_URL
check_if_exists "$MICROSERVICE_WEBCONNECTOR_PORT" MICROSERVICE_WEBCONNECTOR_PORT
check_if_exists "$MICROSERVICE_PORT" MICROSERVICE_PORT
check_if_exists "$HTTP_PORT" HTTP_PORT

if [ "$ENV_VARIABLE_NOT_SET" = true ] ; then
    echo "Missing environment variables, exiting..."
    exit 1
fi

VOLUME_HOME="/var/lib/mysql"
CONF_FILE="/etc/mysql/conf.d/mysql.cnf"
LOG="/var/log/mysql/error.log"

ARCHIVE_DIR="/build/archive/"
WIDGETS_DIR="/build/widgets/"
WEBCONNECTOR_CONFIG_DIR="/build/etc/i5.las2peer.connectors.webConnector.WebConnector.properties"

startCmd=""

addServiceToStartScript () {
    serviceName=$(getProperty "service.name")"".$(getProperty "service.class")"@"$(getProperty "service.version")
    echo "=> Add $serviceName to start script"
    startCmd+=" startService\(\'"$serviceName"\'\)"
}

getProperty () {
    file="ant_configuration/service.properties"
    echo `sed '/^\#/d' $file | grep $1  | tail -n 1 | cut -d "=" -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`
}

startMySQL () {
    echo "=> Starting MySQL ..."
    /usr/bin/mysqld_safe > /dev/null 2>&1 &
    #Check for connectivity
    LIMIT=60
    for (( i=0 ; ; i++ )); do
        if [ ${i} -eq ${LIMIT} ]; then
            echo "Time out. Error log is shown as below:"
            tail -n 100 ${LOG}
            exit 1
        fi
        echo "=> Waiting for confirmation of MySQL service startup, trying ${i}/${LIMIT} ..."
        sleep 1
        mysql -uroot -e "status" > /dev/null 2>&1 && break
    done
}

createMySQLUser () {
    echo "=> Creating MySQL user ${MYSQL_USER} with ${MYSQL_PASS} password now.."
    mysql -uroot -e "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASS}'"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION"
    echo "=> ..MySQL user created!"
}

createDB () {
    echo "Creating MySQL database ${ON_CREATE_DB}"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS \`${ON_CREATE_DB}\`;"
    echo "mysql -uroot -e \"CREATE DATABASE IF NOT EXISTS \`${ON_CREATE_DB}\`;\""
    echo "Database created!"
}

importSql() {
    echo "=> Importing SQL file ${1}"
    mysql -uroot "$ON_CREATE_DB" < "${1}"
}

replaceLinks() {
    dir=$(pwd)
    cd "${ARCHIVE_DIR}/${1}"
    echo "=> Replacing links of widget ${1}"
    sed -i "s#\\\$STEEN_URL\\\$#${DOCKER_URL}#g" ./js/applicationScript.js
    # FIXME: Upon deployment CAE replaces the actual URL with $STEEN_URL:$STEEN_PORT
    #        This removes the path after the host
    sed -i "s#\\\$STEEN_PORT\\\$#${MICROSERVICE_WEBCONNECTOR_PORT}#g" ./js/applicationScript.js
    sed -i "s#\\\$WIDGET_URL\\\$#${DOCKER_URL}#g" ./widget.xml
    sed -i "s#\\\$HTTP_PORT\\\$#${HTTP_PORT}#g" ./widget.xml
    cd "${dir}"
}

copyWidgets() {
    mkdir "$WIDGETS_DIR"
    dir=$(pwd)
    cd "$ARCHIVE_DIR"
    echo "=> Copying widgets now.."
    for widget in ./frontendComponent-*;do
        if [ -d "$widget" ]; then
	    replaceLinks $widget
            cp -a "$widget" "$WIDGETS_DIR"
            echo "=> Copied widget $widget"
        fi
    done
    cd "$dir"
}

updateServiceHttpPort() {
    sed -i "s#<service-http-port>#$MICROSERVICE_WEBCONNECTOR_PORT#g" $WEBCONNECTOR_CONFIG_DIR
}

startMySQL
tail -F $LOG &

#Create user and create database
echo "=> Creating user now.."
createMySQLUser
createDB


#fetch and unzip last build artifact from jenkins
wget $JENKINS_URL/job/$BUILD_JOB_NAME/lastSuccessfulBuild/artifact/*zip*/archive.zip && unzip archive.zip && cd "$ARCHIVE_DIR"

for D in ./microservice-*; do
    if [ -d "$D" ]; then
        cd "$D"
	#copy dependencies from lib and service folder of current microservice to the lib and service folder of the application
	cp  -a lib/. ../../lib/
	cp  -a service/. ../../service/
	#import sql data and create tables
	for sql in db/*.sql; do
            if [ -f "$sql" ]; then
                importSql $sql
            fi
	done
	#generate start script
	cd etc
        for DD in ./i5.las2peer.services.*; do
            cp $DD /build/etc
	    addServiceToStartScript
	done
	cd ../..
    fi
done

updateServiceHttpPort
copyWidgets
#start http server for widgets
cd "$WIDGETS_DIR"
npm install http-server -g
http-server -p $HTTP_PORT &
cd /build
mkdir bin
start_network="java -cp \"lib/*:service/*\" i5.las2peer.tools.L2pNodeLauncher -p "$MICROSERVICE_PORT" uploadStartupDirectory\(\'etc/startup\'\) --service-directory service"$startCmd" startWebConnector"
echo $start_network > /build/bin/start_network.sh
chmod +x /build/bin/start_network.sh
./bin/start_network.sh
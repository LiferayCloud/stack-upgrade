# Necessary configuration

1. Add
   `liferay/configs/local/osgi/configs/com.liferay.portal.search.elasticsearch6.configuration.ElasticsearchConfiguration.config`
   with these contents:

```
operationMode="REMOTE"
indexNamePrefix="liferay-"
transportAddresses="search:9300"
clusterName="liferay_cluster"
```

2. Modify `liferay/configs/local/portal-ext.properties` with these contents:

```
include-and-override=portal-developer.properties

#
# MySQL
#
jdbc.default.driverClassName=com.mysql.cj.jdbc.Driver
jdbc.default.url=jdbc:mysql://database/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
jdbc.default.username=dxpcloud
jdbc.default.password=dxpcloud
web.server.http.port=8080
web.server.protocol=http
```

## Local Development

1. Run the following command to build Liferay with its modules:

```
cd liferay;
./gradlew clean createDockerfile deploy;
```

2. Navigate to the root folder and run `docker-compose up`.
3. To stop the services run `docker-compose down --rmi local`.

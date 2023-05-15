# build
FROM gradle:jdk17 AS build
COPY --chown=gradle:gradle . /home/gradle/src
WORKDIR /home/gradle/src
RUN gradle build --no-daemon 
RUN curl -O -L https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.26.0/opentelemetry-javaagent.jar
# runtime
FROM openjdk:17-jdk-slim AS runtime
RUN mkdir /app
COPY --from=build /home/gradle/src/build/libs/src.jar /app/spring-boot-application.jar
COPY --from=build /home/gradle/src/opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar
ENTRYPOINT ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-Dserver.port=3000", "-jar", "/app/spring-boot-application.jar"]

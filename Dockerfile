# Use intermediate container to protect Azure secret info from published image
# Otherwise there will be traces of the client id and key in the layers of the
# image.

# Pass --build-args for the following KEYVAULT_URL, CLIENT_ID, and CLIENT_KEY
# This is the Keyvault info for where your MySQL connection string, MySQL username
# and password are stored
FROM maven:3.6.2-jdk-8 as BUILD
ARG KEYVAULT_URL
ENV KEYVAULT_URL=$KEYVAULT_URL
ARG CLIENT_ID
ENV KEYVAULT_CLIENT_ID=$CLIENT_ID
ARG CLIENT_KEY
ENV KEYVAULT_CLIENT_KEY=$CLIENT_KEY
COPY . /usr/src/app
RUN mvn --batch-mode -f /usr/src/app/pom.xml clean package

#FROM openjdk:8u232-slim
FROM openjdk:8u232-jre-slim
ENV PORT 8080
EXPOSE 8080
COPY --from=BUILD /usr/src/app/target /opt/target
WORKDIR /opt/target

CMD ["/bin/bash", "-c", "find -type f -name 'todo*.jar' | xargs java -jar"]

# Stage 1: Build with Maven and Temurin JDK 21
FROM maven:3.9.6-eclipse-temurin-21-jammy AS builder
WORKDIR /workspace

# Cache dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy sources and build executable jar
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Minimal Temurin JRE 21 Runtime
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Create a non-privileged application user
RUN groupadd -r safeher && useradd -r -g safeher -d /app -s /sbin/nologin safeher

# Copy jar from builder stage
COPY --from=builder /workspace/target/*.jar app.jar
RUN chown -R safeher:safeher /app

USER safeher:safeher

# Default Render port is 10000 or dynamically injected via PORT env var
ENV PORT=8081 \
    SPRING_PROFILES_ACTIVE=prod \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:${PORT:-8081}/api/health || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]

package com.safeher;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class SafeHerApplication {

    public static void main(String[] args) {
        SpringApplication.run(SafeHerApplication.class, args);
    }
}

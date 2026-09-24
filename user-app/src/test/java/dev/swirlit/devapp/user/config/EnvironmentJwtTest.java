package dev.swirlit.devapp.user.config;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.boot.security.oauth2.server.resource.autoconfigure.OAuth2ResourceServerAutoConfiguration;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class EnvironmentJwtTest {
    @Test
    void sharedRealmRejectsTokensIssuedForAnotherEnvironment() throws Exception {
        var key = new RSAKeyGenerator(2048).keyID("fixture").generate();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        byte[] jwks = new JWKSet(key.toPublicJWK()).toString().getBytes(StandardCharsets.UTF_8);
        server.createContext("/jwks", exchange -> {
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, jwks.length);
            try (var body = exchange.getResponseBody()) { body.write(jwks); }
        });
        server.start();
        try {
            var sources = new YamlPropertySourceLoader().load("application", new ClassPathResource("application.yml"));
            var runner = new ApplicationContextRunner()
                    .withConfiguration(AutoConfigurations.of(OAuth2ResourceServerAutoConfiguration.class))
                    .withInitializer(context -> sources.forEach(source -> context.getEnvironment().getPropertySources().addLast(source)))
                    .withPropertyValues("JWT_ISSUER_URI=https://keycloak.example.com/auth/realms/company",
                            "JWT_JWK_SET_URI=http://127.0.0.1:" + server.getAddress().getPort() + "/jwks",
                            "JWT_AUDIENCE=devapp-prod-web");
            var signer = new RSASSASigner(key);
            var issued = Instant.now();
            var prod = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("fixture").build(),
                    new JWTClaimsSet.Builder().issuer("https://keycloak.example.com/auth/realms/company")
                            .subject("visitor").audience("devapp-prod-web").issueTime(Date.from(issued))
                            .expirationTime(Date.from(issued.plusSeconds(60))).build());
            prod.sign(signer);
            var integration = new SignedJWT(prod.getHeader(), new JWTClaimsSet.Builder(prod.getJWTClaimsSet())
                    .audience("devapp-int-web").build());
            integration.sign(signer);
            runner.run(context -> {
                var decoder = context.getBean(JwtDecoder.class);
                assertEquals("visitor", decoder.decode(prod.serialize()).getSubject());
                assertThrows(JwtException.class, () -> decoder.decode(integration.serialize()));
            });
        } finally {
            server.stop(0);
        }
    }
}

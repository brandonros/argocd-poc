package otel;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PingController {
  private static final Logger logger = LoggerFactory.getLogger(PingController.class);

  @RequestMapping(method = RequestMethod.GET, path = "/ping")
  public ResponseEntity<String> getPing() {
    logger.info("ping");
    return ResponseEntity.ok("pong");
  }
}

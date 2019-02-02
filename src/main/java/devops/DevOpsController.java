package devops;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping; @RestController

public class DevOpsController {
  private static final Logger LOGGER = LoggerFactory.getLogger(DevOpsController.class);
    @RequestMapping("/")
    public String index() {
      LOGGER.info("EVENTO:{\"saludo\":\"Hola\"}");
      LOGGER.debug("DEBUG message");
      LOGGER.warn("WARN message");
      LOGGER.error("ERROR message");

      return "Aplicación de laboratorio v2";

    }
}

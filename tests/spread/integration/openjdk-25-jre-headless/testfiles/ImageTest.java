import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import javax.imageio.ImageIO;

public class ImageTest {

    public static void main(String[] args) throws IOException {
        int width = 400;
        int height = 200;
        BufferedImage bufferedImage = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g2d = bufferedImage.createGraphics();
        g2d.setColor(Color.WHITE);
        g2d.fillRect(0, 0, width, height);
        g2d.setColor(Color.BLACK);
        g2d.setFont(new Font("Serif", Font.BOLD, 24));
        g2d.drawString("Hello, World!", 50, 100);
        g2d.dispose();
        File file = new File("HelloWorld.png");
        ImageIO.write(bufferedImage, "png", file);
    }
}

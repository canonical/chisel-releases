
import java.awt.Color;
import java.awt.FontMetrics;
import java.awt.Graphics;
import java.awt.image.BufferedImage;

public class ImageTest {
    public static void main(String[] args) throws Exception {
        BufferedImage bi = new BufferedImage(1000, 1000, BufferedImage.TYPE_INT_RGB);
        Graphics g = bi.createGraphics();
        FontMetrics fm = g.getFontMetrics();
        int len = fm.stringWidth("test");
        if (len <= 0)
            throw new RuntimeException("Font length should be positive");
        g.setColor(Color.BLUE);
        g.fillRect(0, 0, 1000, 1000);
        g.drawChars("test".toCharArray(), 0, "test".length(), 0, 0);
        g.dispose();
    }
}

import java.util.prefs.*;

public class PrefsTest {
    public static void main(String[] args) {
        if ("put".equals(args[0])) {
            Preferences.userRoot().put("a", "b");
        } else if ("get".equals(args[0])) {
            if (!"b".equals(Preferences.userRoot().get("a", null))) {
                throw new RuntimeException("Unable to read the preference");
            }
        }
    }
}

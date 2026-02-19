import java.lang.management.ManagementFactory;
import javax.management.Attribute;
import javax.management.AttributeList;
import javax.management.AttributeNotFoundException;
import javax.management.DynamicMBean;
import javax.management.InstanceAlreadyExistsException;
import javax.management.InvalidAttributeValueException;
import javax.management.MBeanException;
import javax.management.MBeanInfo;
import javax.management.MBeanRegistrationException;
import javax.management.MBeanServer;
import javax.management.MBeanServerConnection;
import javax.management.MalformedObjectNameException;
import javax.management.NotCompliantMBeanException;
import javax.management.ObjectName;
import javax.management.ReflectionException;
import javax.management.remote.*;

import com.sun.tools.attach.*;


public class TestJMX implements TestJMXMBean {

    static final String CONNECTOR_ADDRESS =
        "com.sun.management.jmxremote.localConnectorAddress";

    @Override
    public void test() {

    }

    public static void main(String[] args) throws Throwable {
        ObjectName objectName = new ObjectName("test:type=basic,name=mbeantest");
        MBeanServer server = ManagementFactory.getPlatformMBeanServer();
        server.registerMBean(new TestJMX(), objectName);
        JMXServiceURL url = new JMXServiceURL("service:jmx:rmi:///jndi/rmi://localhost:5000/jmxrmi");
        int count = JMXConnectorFactory.connect(url)
            .getMBeanServerConnection()
            .getMBeanCount();
        System.out.println(count);
    }
}

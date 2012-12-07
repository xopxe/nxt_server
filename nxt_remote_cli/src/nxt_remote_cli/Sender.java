/*
 * Sender.java
 *
 * Created on September 14, 2007, 1:09 AM
 */

package nxt_remote_cli;

import java.io.*;
import java.net.*;

/**
 *
 * @author xopxe
 */
public class Sender {
    
    private static DatagramSocket clientSocket = null;
    private static InetAddress IPAddress=null;
    private static int port;
    
    
    /** Creates a new instance of Sender */
    private Sender() {
    }
    
    public static void setServer(String server, int port) {
        try {
            IPAddress = InetAddress.getByName(server);
        } catch (UnknownHostException ex) {
            ex.printStackTrace();
        }
        
        if (clientSocket!=null) {
            clientSocket.close();
        }
        try {
            clientSocket = new DatagramSocket();
        } catch (SocketException ex) {
            ex.printStackTrace();
        }
        Sender.port=port;
    }
    
    public static void send(String s) {
        //System.out.println("--"+s +" a "+IPAddress.getHostAddress()+ ":"+port+" --- " +clientSocket.getLocalSocketAddress());
        byte[] sendData = new byte[1024];
        sendData = s.getBytes();
        DatagramPacket sendPacket =
                new DatagramPacket(sendData, sendData.length, IPAddress, port);
        try {
            clientSocket.send(sendPacket);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        
    }
    
    
}

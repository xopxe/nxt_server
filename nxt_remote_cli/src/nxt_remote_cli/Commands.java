/*
 * Commands.java
 *
 * Created on September 14, 2007, 1:53 AM
 */

package nxt_remote_cli;

/**
 *
 * @author xopxe
 */
public class Commands {
    
//IO Port:
    public static int NXT_MOTOR_A   = 0x00;
    public static int NXT_MOTOR_B   = 0x01;
    public static int NXT_MOTOR_C   = 0x02;
    public static int NXT_MOTOR_ALL = 0xFF;
    
//Output mode:
    public static int NXT_MOTOR_ON  = 0x01;
    public static int NXT_BRAKE     = 0x02;
    public static int NXT_REGULATED = 0x04;
    
//Output regulation modes:
    public static int NXT_REGULATION_MODE_IDLE        = 0x00;
    public static int NXT_REGULATION_MODE_MOTOR_SPEED = 0x01;
    public static int NXT_REGULATION_MODE_MOTOR_SYNC  = 0x02;
    
//Output run states:
    public static int NXT_MOTOR_RUN_STATE_IDLE        = 0x00;
    public static int NXT_MOTOR_RUN_STATE_RAMPUP      = 0x10;
    public static int NXT_MOTOR_RUN_STATE_RUNNING     = 0x20;
    public static int NXT_MOTOR_RUN_STATE_RAMPDOWN    = 0x40;
    
    
    
    /** Creates a new instance of Commands */
    private Commands() {
    }

    public static String getMotorOutput(String r, int motor, int vel) {
        if (vel==0) {
            return r+",set_output_state,"+motor+",0,"+NXT_BRAKE+","
                    +NXT_REGULATION_MODE_IDLE+",0,"+NXT_MOTOR_RUN_STATE_IDLE+",0";
        } else{
            return r+",set_output_state,"+motor+","+vel+","+(NXT_MOTOR_ON|NXT_REGULATED)+","
                    +NXT_REGULATION_MODE_MOTOR_SPEED+",0,"+NXT_MOTOR_RUN_STATE_RUNNING+",0";
        }
    }
    
    public static String getAllMotorStop(String r) {
        return r+",set_output_state,"+NXT_MOTOR_ALL+",0,"+NXT_BRAKE+","
                +NXT_REGULATION_MODE_IDLE+",0,"+NXT_MOTOR_RUN_STATE_IDLE+",0";
    }

    public static String getBatteryLevel(String r) {
    	return r+",get_battery_level";
  
    }

    public static String getBeep(String r) {
        return r+",play_sound_file,0,! Attention.rso";
        
    }
    
    public static String getStartProgram(String r, String prog) {
        return r+",start_program," +prog;
        
    }
    
    public static String getStopProgram(String r) {
        return r+",stop_program"; 
    }
}

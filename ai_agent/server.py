from fastmcp import FastMCP
from booking_system import OptimizedBookingSystem
import threading
import time

mcp = FastMCP("My MCP Server")


@mcp.tool
def booking() -> bool:
    username = "u3606584"
    password = ""
    room_type = 29
    location = 5
    date = "20251220"
    t = "14001500"
    rooms = [str(room) for room in range(258, 267)] + [str(room) for room in range(268, 272)] + ["274", "275"]
    
    booking_system = OptimizedBookingSystem(username=username, password=password, location=location, type=room_type, date=date, sessions=t)
    
    try:
        booking_system.initialize_multiple_drivers()
    
        login_threads = []
        for _, driver in enumerate(booking_system.drivers):
            thread = threading.Thread(target=booking_system.pre_login, args=(driver,))
            login_threads.append(thread)
            thread.start()
            
        for thread in login_threads:
            thread.join()
            time.sleep(0.3)
            
        booking_system.concurrent_booking_attempt(rooms)
        
        if booking_system.successful_bookings:
            print("Booking successful for rooms:", booking_system.successful_bookings)
            for session, room in booking_system.successful_bookings.items():
                print("Booked room {} for session {}".format(room, session))
            
            if len(booking_system.successful_bookings) == len(booking_system.sessions):
                print("All sessions booked successfully.")
                
            else:
                print("Some sessions could not be booked.")
            return True
        else:
            return False
        
    except Exception as e:
        print("An error occurred during booking:", str(e))
        return False
    

    
if __name__ == "__main__":
    mcp.run(transport="http", port=8000)
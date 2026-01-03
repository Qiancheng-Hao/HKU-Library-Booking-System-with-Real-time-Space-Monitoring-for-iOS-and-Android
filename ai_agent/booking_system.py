import time
import threading
import random
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    StaleElementReferenceException, 
    NoSuchElementException, 
    ElementNotInteractableException,
    TimeoutException,
    WebDriverException
)
from webdriver_manager.chrome import ChromeDriverManager

class OptimizedBookingSystem:
    def __init__(self, username, password, location, type, date, sessions):
        self.username = username
        self.password = password
        self.location = location
        self.type = type
        self.date = date
        self.sessions = sessions if isinstance(sessions, list) else [sessions]  
        self.base_url = "https://booking.lib.hku.hk/Secure/NewBooking.aspx"
        self.drivers = []
        self.successful_bookings = {} 
        self.booking_lock = threading.Lock()
        
        # XPath and selectors
        self.username_xpath = "//input[@title='Please enter your portal uid or library card number']"
        self.password_xpath = "//input[@title='Please enter your pin']"
        self.login_button_xpath = '//*[@id="hkulauth"]/p[6]/input[1]'
        self.submit_button_id = 'main_btnSubmit'
        self.yes_button_id = 'main_btnSubmitYes'
        
    def create_driver(self):
        chrome_options = webdriver.ChromeOptions()
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument("--disable-extensions")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-logging")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--headless")
        
        driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
        driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
        return driver
    
    def initialize_multiple_drivers(self, num_drivers=3):
        print(f"Initializing {num_drivers} browser instances...")
        for i in range(num_drivers):
            try:
                driver = self.create_driver()
                self.drivers.append(driver)
                print(f"Driver {i+1} initialized successfully")
            except Exception as e:
                print(f"Failed to initialize driver {i+1}: {e}")
    
    def close_all_drivers(self):
        for driver in self.drivers:
            try:
                driver.quit()
            except:
                pass
        self.drivers.clear()
    
    def pre_login(self, driver):
        """Pre-login to the booking system"""
        try:
            # Visit any booking page to trigger login (using the first session)
            test_url = f"{self.base_url}?library={self.location}&ftype={self.type}&facility=999&date={self.date}&session={self.sessions[0]}"
            driver.get(test_url)
            
            wait = WebDriverWait(driver, 15)

            # Wait for and fill in login information
            print("Pre-login: Waiting for login form...")
            input_field = wait.until(EC.presence_of_element_located((By.XPATH, self.username_xpath)))
            password_field = wait.until(EC.presence_of_element_located((By.XPATH, self.password_xpath)))
            login_button = wait.until(EC.element_to_be_clickable((By.XPATH, self.login_button_xpath)))
            
            input_field.clear()
            input_field.send_keys(self.username)
            password_field.clear()
            password_field.send_keys(self.password)
            
            # Random short sleep to mimic human behavior
            time.sleep(random.uniform(0.1, 0.5))
            login_button.click()
            
            print("Pre-login completed successfully")
            time.sleep(2)
            return True
            
        except Exception as e:
            print(f"Pre-login failed: {e}")
            return False
    
    def attempt_booking_with_retry(self, driver, room, session, max_retries=3):
        """Attempt booking with retry mechanism"""
        for attempt in range(max_retries):
            try:
                return self.attempt_single_booking(driver, room, session)
            except (TimeoutException, WebDriverException) as e:
                if attempt < max_retries - 1:
                    wait_time = (2 ** attempt) + random.uniform(0, 1) 
                    print(f"Room {room} session {session} attempt {attempt + 1} failed, retrying in {wait_time:.1f}s: {e}")
                    time.sleep(wait_time)
                else:
                    print(f"Room {room} session {session} failed after {max_retries} attempts")
                    return False
        return False
    
    def attempt_single_booking(self, driver, room, session):
        """Try to book a single room for a single session"""
        # Check if there is already a successful booking
        with self.booking_lock:
            if session in self.successful_bookings:
                return False
        
        try:
            url = f"{self.base_url}?library={self.location}&ftype={self.type}&facility={room}&date={self.date}&session={session}"
            
            print(f"Attempting to book room {room} for session {session}...")
            driver.get(url)

            # Increase wait time and add debug information
            wait = WebDriverWait(driver, 10)

            # Check if the page has loaded correctly
            time.sleep(2)  # Give the page more time to load

            # Add debug information
            page_title = driver.title
            current_url = driver.current_url
            print(f"Room {room} session {session}: Page title: {page_title}")
            print(f"Room {room} session {session}: Current URL: {current_url}")
            
            # Check if login is required
            if "login" in current_url.lower() or "auth" in current_url.lower():
                print(f"Room {room} session {session}: Need to login again, attempting re-login...")
                try:
                    input_field = wait.until(EC.presence_of_element_located((By.XPATH, self.username_xpath)))
                    password_field = wait.until(EC.presence_of_element_located((By.XPATH, self.password_xpath)))
                    login_button = wait.until(EC.element_to_be_clickable((By.XPATH, self.login_button_xpath)))
                    
                    input_field.clear()
                    input_field.send_keys(self.username)
                    password_field.clear()
                    password_field.send_keys(self.password)
                    login_button.click()
                    time.sleep(3)  # Wait for login to complete
                    print(f"Room {room} session {session}: Re-login completed")
                except Exception as e:
                    print(f"Room {room} session {session}: Re-login failed: {e}")
                    return False
            
            # try to click the submit button
            try:
                submit_button = wait.until(EC.element_to_be_clickable((By.ID, self.submit_button_id)))
                submit_button.click()
                print(f"Room {room} session {session}: Submit button clicked")
                time.sleep(2) 
                
                # Debug information before looking for Yes button
                print(f"Room {room} session {session}: Looking for Yes button...")
                print(f"Room {room} session {session}: Current URL: {driver.current_url}")
                
                try:
                    # Click the confirmation "Yes" button
                    yes_button = wait.until(EC.element_to_be_clickable((By.ID, self.yes_button_id)))
                    yes_button.click()
                    print(f"Room {room} session {session}: Confirmation clicked")

                    # Quick check for success status
                    time.sleep(1)
                    page_source = driver.page_source.lower()
                    
                    if "success" in page_source or "confirmed" in page_source or "booked" in page_source:
                        with self.booking_lock:
                            if session not in self.successful_bookings:
                                self.successful_bookings[session] = room
                                print(f"SUCCESSFULLY BOOKED ROOM {room} FOR SESSION {session}!")
                                return True                 
                except Exception as e:
                    print(f"Room {room} session {session}: No confirmation dialog or booking failed: {e}")
                    return False
                    
            except Exception as e:
                print(f"Room {room} session {session}: Submit button not found or not clickable: {e}")
                return False
                
        except Exception as e:
            print(f"Room {room} session {session}: General error: {e}")
            return False
        
        return False
    
    def concurrent_booking_attempt(self, rooms):
        """Attempt to book rooms concurrently using multiple threads"""
        total_threads = 3
        threads_per_session = total_threads // len(self.sessions)

        print(f"Starting concurrent booking for {len(rooms)} rooms and {len(self.sessions)} sessions...")
        print(f"Total threads: {total_threads}, threads per session: {threads_per_session}")

        # Initialize enough drivers
        # required_drivers = min(total_threads, len(rooms) * len(self.sessions))
        # if len(self.drivers) < required_drivers:
        #     print(f"Initializing additional drivers... (need {required_drivers}, have {len(self.drivers)})")
        #     additional_drivers = required_drivers - len(self.drivers)
        #     for i in range(additional_drivers):
        #         try:
        #             driver = self.create_driver()
        #             self.drivers.append(driver)
        #             # Pre-login the new driver
        #             self.pre_login(driver)
        #             print(f"Additional driver {i+1} initialized and logged in")
        #         except Exception as e:
        #             print(f"Failed to initialize additional driver {i+1}: {e}")
        
        # Create room-driver pairs for each session
        all_tasks = []
        driver_index = 0
        
        for session in self.sessions:
            session_tasks = []
            for i, room in enumerate(rooms[:threads_per_session]):  # Each session uses a specified number of rooms
                if driver_index < len(self.drivers):
                    driver = self.drivers[driver_index]
                    session_tasks.append((room, driver, session))
                    driver_index += 1
            all_tasks.extend(session_tasks)
            print(f"Session {session}: {len(session_tasks)} tasks prepared")

        # Use thread pool to execute
        with ThreadPoolExecutor(max_workers=total_threads) as executor:
            future_to_task = {
                executor.submit(self.attempt_booking_with_retry, driver, room, session): (room, session)
                for room, driver, session in all_tasks
            }
            
            completed_sessions = set()
            
            for future in as_completed(future_to_task):
                room, session = future_to_task[future]
                try:
                    success = future.result()
                    if success:
                        completed_sessions.add(session)
                        print(f"Booking thread for room {room} session {session} completed successfully!")

                        # If all sessions booked successfully, cancel remaining tasks
                        if len(completed_sessions) == len(self.sessions):
                            print("All sessions booked successfully! Cancelling remaining tasks...")
                            for f in future_to_task:
                                if f != future:
                                    f.cancel()
                            break
                except Exception as e:
                    print(f"Room {room} session {session} booking thread generated an exception: {e}")

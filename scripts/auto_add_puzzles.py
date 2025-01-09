"""
Script to automatically adds puzzles to Galackboard. Requires Selenium.

Steps to setup:
- Set the login credentials (usernames, URLs, passwords) to appropriate values
- Fill in the method `get_available_puzzles`
- Install Selenium and run the script!
"""

from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from urllib.parse import quote
from re import compile
from time import sleep
import json
import re
import sys


GALACKBOARD_BASE_URL = None
GALACKBOARD_PASSWORD = None
HUNT_LOGIN_PAGE = None
HUNT_LOGIN_USERNAME = None
HUNT_LOGIN_PASSWORD = None

# If true, the script won't actually add new puzzles to Galackboard
DRY_RUN = False

def get_available_puzzles(driver):
	"""
	Provide code to fetch the list of available puzzles.
	This code will vary by hunt year and depends on how the website is
	structured.

	The return value should be a list of tuples. Each tuple should have the
	form (puzzle title, puzzle URL).
	"""

	r = []
	driver.get('https://starrats.org')
	sleep(3)
	for k in driver.find_elements(By.CSS_SELECTOR, 'a'):
		if 'www.starrats.org/puzzle/' in k.get_attribute('href'):
			r.append( (k.get_attribute('innerHTML'), k.get_attribute('href')) )

	return r

##################################################################
# You probably shouldn't need to edit anything below this point! #
##################################################################

if not GALACKBOARD_BASE_URL:
	print('You need to set GALACKBOARD_BASE_URL! Exiting.')
	sys.exit()

NEW_PUZZLE_URL = GALACKBOARD_BASE_URL + "/newPuzzle/{}/{}"

driver = webdriver.Chrome()

driver.get(GALACKBOARD_BASE_URL)
driver.find_element(By.ID, 'passwordInput').send_keys(GALACKBOARD_PASSWORD)
driver.find_element(By.ID, 'nickInput').send_keys('puzzleAdderBot')
driver.find_element(By.ID, 'nickInput').submit()
sleep(3)

#driver.get(HUNT_LOGIN_PAGE)
#driver.find_elements_by_name('password') [0].send_keys(HUNT_LOGIN_PASSWORD)
#driver.find_element_by_id('username').send_keys(HUNT_LOGIN_USERNAME)
#driver.find_element_by_id('username').submit()
#sleep(3)

def url_to_slug(url):
	return re.search(r'\/([^\/]+)\/?$', url)[1]

while True:
	print(f'reloading puzzle page ({datetime.now().strftime("%H:%M:%S")})')
	new_puzzles = get_available_puzzles(driver)

	driver.get(GALACKBOARD_BASE_URL)
	sleep(3)
	existing_puzzle_slugs = [
		url_to_slug(k.get_attribute('href'))
		for k in driver.find_elements(By.CLASS_NAME, 'pull-right')
		if k.get_attribute('title') == 'Link to hunt site'
	]

	for (title, href) in new_puzzles:
		slug = url_to_slug(href)
		if slug in existing_puzzle_slugs:
			continue

		new_puzzle_url = NEW_PUZZLE_URL.format(quote(title, safe=''), quote(href, safe=''))
		print(f'Adding puzzle {slug}')
		if not DRY_RUN:
			driver.get(new_puzzle_url)
		sleep(3)
	
	sleep(20)
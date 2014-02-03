import sys
import re
import urllib
import MLStripper
import sys
	
def py_parser(html):
	#get html from url
	file = urllib.urlopen(html)
	html = ""
	for line in file:
		html += line
	#strip html tags
	clean_html = MLStripper.strip_tags(html)
	#process table
	process_table(clean_html)

#processes table, prints results or "skipped" if it's not a table
def process_table(clean_html):
	rx_bills = re.compile('\(.*Bolet(.*\d*\.{0,1}\d+-\d+)*.*\)')
	bills = rx_bills.findall(clean_html)

	bill_nums = []
	rx_bill_num = re.compile('(\d{0,3})[^0-9]*(\d{0,3})[^0-9]*(\d{1,3})[^0-9]*(-)[^0-9]*(\d{2})')
	for bill in bills:
		for bill_num_array in rx_bill_num.findall(bill):
			bill_num = "".join(bill_num_array)
			bill_nums.append(bill_num)

	#get date
	# rx_date = re.compile('(\d{1,2}) (?:de ){0,1}(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre) (?:de ){0,1}(\d{4})')
	# date = rx_date.findall(clean_html)
	#date is array of arrays
	# date = date[0]
	# date = date_sp_2_en(date)
	#get legislature
	# rx_legislature = re.compile('LEGISLATURA.+(\d{3})')
	# legislature = rx_legislature.findall(clean_html)
	#get session
	# rx_session = re.compile('Sesi.+?(\d{1,3})')
	# session = rx_session.findall(clean_html)
	
	#print to stdout
	# if bill_nums and date and legislature and session:
	# 	print "bill numbers: " + ",".join(bill_nums) + ";",
	# 	print "date: " + " ".join(date) + ";",
	# 	print "legislature: " + legislature[0] + ";",
	# 	print "session: " + session[0],

	# else:
	# 	print "skipped"

	print "bill numbers: " + ",".join(bill_nums) + ";",
	# print "date: " + " ".join(date) + ";",
	# print "legislature: " + legislature[0] + ";",
	# print "session: " + session[0],

#from d/m/y to m/d/y
#month name from spanish to english
def date_sp_2_en(date):
	day = date [0]
	month = date [1]
	year = date [2]
	
	months = {'enero' : 'january', 'febrero' : 'february', 'marzo' : 'march', 'abril' : 'april', 'mayo' : 'may', 'junio' : 'june', 'julio' : 'july', 'agosto' : 'august', 'septiembre' : 'september', 'octubre' : 'october', 'noviembre' : 'november', 'diciembre' : 'december'}
	
	en_date = [months[month], day, year]
	return en_date

if __name__ == '__main__':
	#print '--------------------------->'
	#print sys.argv[1]
	#print '<---------------------------'
	py_parser(sys.argv[1])

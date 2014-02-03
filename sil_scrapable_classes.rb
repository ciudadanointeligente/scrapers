# coding: utf-8
require './scrapable_classes'

class CongressTable < StorageableInfo

	def initialize()
		super()
		@model = 'tables'
		@API_url = 'http://localhost:3000/'
		@chamber = ''
	end

	def save formatted_info
		puts 'formatted_info'
		puts formatted_info
		puts '/formatted_info'
		# post formatted_info
	end

	def post formatted_info
		RestClient.post @API_url + @model, {low_chamber_agenda: formatted_info}, {:content_type => :json}
	end

	def format info
		formatted_info = {
    		:uid => info['legislature'] + '-' + info['session'],
            :date => info['date'],
            # :chamber => @chamber,
            :legislature => info['legislature'],
            :session => info['session'],
            :bill_list => info['bill_list']
		}
	end

	def get_link(url, base_url, xpath)
                html = Nokogiri::HTML.parse(read(url), nil, 'utf-8')
                base_url + html.xpath(xpath).first['href']
        end
end

class CurrentHighChamberTable < CongressTable
	def initialize()
		super()
		@location = 'http://www.senado.cl/appsenado/index.php?mo=sesionessala&ac=doctosSesion&tipo=27'
		@base_url = 'http://www.senado.cl'
		@chamber = 'Senado'
	end

	#python scripts reads and parses
	def process
			puts 'processing'
			puts doc_locations
                doc_locations.each do |doc_location|
                        begin
                        	puts 'begun'
                                doc = read doc_location
                                info = get_info doc
                                puts 'info'
                                puts info
                                puts '/info'
                                formatted_info = format info
                                puts 'formatted_info'
                                puts formatted_info
                                puts '/formatted_info'
                                save formatted_info
                        rescue Exception=>e
                        end
                end
        end

	def doc_locations
		html = Nokogiri::HTML(read(@location), nil, 'utf-8')
		doc_locations = Array.new

		# doc_locations.push @base_url + html.xpath("//a[@class='citaciones']/@href").to_s.strip
		doc_locations.push @base_url + html.xpath("//a[@class='citaciones']/@href").to_s.strip
		puts "doc_locations"
		puts doc_locations
		puts "/doc_locations"

		# html.xpath('//*[@id="contentTopI"]/div[1]/div[2]/table//tr[(position()>2)]').each do |tr|
		# 	table_url = tr.at_xpath('td[5]/a/@href').to_s.strip
  #                    	doc_locations.push @base_url + table_url
		# end
		return doc_locations
	end

	def get_info doc
		info = Hash.new

		puts "doc"
		puts doc
		puts "/doc"

		rx_bills = /Bolet(.*\d+-\d+)*/
		bills = doc.scan(rx_bills)
		
		bill_list = []
		rx_bill_num = /(\d{0,3})[^0-9]*(\d{0,3})[^0-9]*(\d{1,3})[^0-9]*(-)[^0-9]*(\d{2})/
		bills.each do |bill|
			bill.first.scan(rx_bill_num).each do |bill_num_array|
				bill_num = (bill_num_array).join('')
				bill_list.push(bill_num)
			end
		end
                #exec python script
                # puts 'running python script'
                # scraped_vals = %x[python table_parser.py '#{doc}'].gsub(/\n/,' ')
                # puts '/running python script'
                # puts 'scraped_vals'
                # puts scraped_vals
                # puts '/scraped_vals'
		
                # info['session'] = scraped_vals.scan(/session: (\d*)/).flatten[0]
                # info['legislature'] = scraped_vals.scan(/legislature: (\d*)/).flatten[0]
                # info['date'] = scraped_vals.scan(/date: (\w*) (\d{1,2}) (\d{4})/).join(' ')

                # puts '/getting_info'
        info['bill_list'] = bill_list
		info
        end
end

class CurrentLowChamberTable < CongressTable

	def initialize()
        super()
		@model = 'low_chamber_agendas'
        @location = 'http://www.camara.cl/trabajamos/sala_documentos.aspx?prmTIPO=TABLA'
        @chamber = 'C.Diputados'
		@session_base_url = 'http://www.camara.cl/trabajamos/'
		@table_base_url = 'http://www.camara.cl'
		@session_xpath = '//*[@id="detail"]/table/tbody/tr[1]/td[2]/a'
		# @table_xpath = '//*[@id="ctl00_mainPlaceHolder_docpdf"]/li/a'
		@table_xpath = '//*[@id="detail"]/table/tbody/tr[1]/td/a'
        end

#----- REDEFINED -----
	def doc_locations
		doc_locations_array = Array.new
		# session_url = get_link(@location, @session_base_url, @session_xpath)
		table_url = get_link(@location, @table_base_url, @table_xpath)
		puts "table_url"
		puts table_url
		puts "/table_url"
		# puts session_url
		# puts table_url
		doc_locations_array.push(table_url)
                # get all with doc.xpath('//*[@id="detail"]/table/tbody/tr[(position()>0)]/td[2]/a/@href').each do |tr|
	end

	def get_info doc
		# get bills
		rx_bills = /Bolet(.*\d+-\d+)*/
		bills = doc.scan(rx_bills)
		
		bill_list = []
		rx_bill_num = /(\d{0,3})[^0-9]*(\d{0,3})[^0-9]*(\d{1,3})[^0-9]*(-)[^0-9]*(\d{2})/
		bills.each do |bill|
			bill.first.scan(rx_bill_num).each do |bill_num_array|
				bill_num = (bill_num_array).join('')
				bill_list.push(bill_num)
			end
		end

		#get date
		rx_date = /(\d{1,2}) (?:de ){0,1}(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre) (?:de ){0,1}(\d{4})/
		date_sp = doc.scan(rx_date).first
		date = date_sp_2_en(date_sp).join(' ')

		# get legislature
		rx_legislature = /(\d{3}).+LEGISLATURA/
		legislature = doc.scan(rx_legislature).flatten.first

		# get session
		rx_session = /Sesi.+?(\d{1,3})/
		session = doc.scan(rx_session).flatten.first

		return {'bill_list' => bill_list, 'date' => date, 'legislature' => legislature, 'session' => session}
	end

	def date_sp_2_en date
		day = date [0]
		month = date [1]
		year = date [2]
	
		months = {'enero' => 'january', 'febrero' => 'february', 'marzo' => 'march', 'abril' => 'april', 'mayo' => 'may', 'junio' => 'june', 'julio' => 'july', 'agosto' => 'august', 'septiembre' => 'september', 'octubre' => 'october', 'noviembre' => 'november', 'diciembre' => 'december'}
	
		en_date = [months[month], day, year]
		return en_date
	end

end



class BillCategory < StorageableInfo

	def initialize
		super()
		@location = 'bill_categories'
		@bills_location = 'bills'
		@match_info_location = 'categories'
		@model = 'bills'

		@bills = parse(read(@bills_location))
		@categorized_bills = parse(read(@match_info_location))
	end

	def save formatted_info
		post formatted_info
	end

	def doc_locations
		parse(read(@location))
	end

	def parse doc
		doc_hash = {}
		doc.split(/\n/).each do |pair|
			key, val = pair.split(/\t/)
			if doc_hash.has_key?(key)
				doc_hash[key].push(val)
			else
				doc_hash.store(key, [val])
			end
		end
		doc_hash
	end

	def get_info doc
		bill, cat_ids = doc
		cat_array = []
		cat_ids.each do |cat_id|
			cat_val = @categorized_bills[cat_id]
			cat_array.push(cat_val)
		end
		[bill, cat_array]
	end

	def format info
		puts 'in format info'
		bill, categories = info
	        formatted_info = {
                :uid => @bills[bill].first,
                :matters => categories.join('|')
        	}
	end
end

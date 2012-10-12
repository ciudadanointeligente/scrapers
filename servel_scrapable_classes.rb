# coding: utf-8
require './scrapable_classes'

class ServelDB < StorageableInfo

	def initialize(max, min)
                super()
                @location = 'http://consulta.servel.cl'
		# Cambiar!!!
		@params = 'btnconsulta=SUBMIT&__ASYNCPOST=true&__EVENTARGUMENT=&__EVENTTARGET=&__EVENTVALIDATION=%2FwEWAwL9iqj%2BBQK7%2B6rmDAKVq8qQCQ%3D%3D&__VIEWSTATE=%2FwEPDwUJNzUwMjI5OTkzD2QWAgIDD2QWAgIDDw8WBB4EVGV4dGUeB0VuYWJsZWRoZGRk&hdfl=&txtRUN='
		@param_names = {
				'btn' => 'btnconsulta',
				'event' => '__EVENTVALIDATION',
				'view' => '__VIEWSTATE',
				'rut' => 'txtRUN'
				}
		@ruts = Integer(max).downto(Integer(min))
		@file_name = 'servel_'+max.to_s+'-'+min.to_s
		#Set xpaths
		@xpath_view = '//*[@id="__VIEWSTATE"]'
		@xpath_event = '//*[@id="__EVENTVALIDATION"]'
		@xpath_rut = '//*[@id="lbl_run"]'
		@xpath_name = '//*[@id="lbl_nombre"]/text()'
		@xpath_gender = '//*[@id="lbl_sexo"]'
		@xpath_electoral_adress = '//*[@id="lbl_domelect"]/text()'
		@xpath_circunscriptional_adress = '//*[@id="lbl_cirelect"]'
		@xpath_commune = '//*[@id="lbl_comuna"]'
		@xpath_province = '//*[@id="lbl_provincia"]'
		@xpath_region = '//*[@id="lbl_region"]'
		@xpath_table = '//*[@id="lbl_mesa"]'
		@xpath_voting_place = '//*[@id="lbl_localv"]'
		@xpath_voting_place_adress = '//*[@id="lbl_direcvocal"]'
		@xpath_vocal_condition = '//*[@id="lbl_codvocal"]/text()'
		@xpath_scrutineer_condition = '//*[@id="lbl_codcolegio"]/text()'
		#Get initial keys
		data = open(@location).read
		html = Nokogiri::HTML(data, nil, 'utf-8')
		@param_values = {
				'btn' => 'SUBMIT',
				'view' => CGI::escape(html.xpath(@xpath_view).first['value']),
				'event' => CGI::escape(html.xpath(@xpath_event).first['value']),
				'rut' => ''
				}
	end

	def params_url rut
		@param_values['rut'] = rut
		params = @param_names.merge(@param_values){|key, name, value| [name, value].join('=')}
		params.values.join('&')
	end

	def update_params view, event
		@param_values['view'] = view
		@param_values['event'] = event
	end
		

	# doc_locations doesn't have the method each
	def process
		doc_locations do |doc_location|
			begin
				#doc = read doc_location
				info = get_info doc_location
				formatted_info = format info
				save formatted_info
			rescue Exception=>e
				p e
			end
		end
	end

	def doc_locations
		for rut in @ruts
			p rut
			yield rut.to_s+verificador(rut)
		end
	end

	def format info
		info
	end

	def get_info rut
		params = params_url rut
		data = RestClient.post @location, params
		html = Nokogiri::HTML(data, nil, 'utf-8')
		#update keys
		view = CGI::escape(html.xpath(@xpath_view).first['value'])
		event = CGI::escape(html.xpath(@xpath_event).first['value'])
		update_params view, event
		#get data with xpath
		parsed_data = {
			'rut' => html.xpath(@xpath_rut).first.children.text.strip,
			'name' => html.xpath(@xpath_name).first.text.strip,
			'gender' => html.xpath(@xpath_gender).first.children.text.strip,
			'electoral_adress' => html.xpath(@xpath_electoral_adress).first.text.strip,
			'circunscriptional_adress' => html.xpath(@xpath_circunscriptional_adress).first.children.text.strip,
			'commune' => html.xpath(@xpath_commune).first.children.text.strip,
			'province' => html.xpath(@xpath_province).first.children.text.strip,
			'region' => html.xpath(@xpath_region).first.children.text.strip,
			'table' => html.xpath(@xpath_table).first.children.text.strip,
			'voting_place' => html.xpath(@xpath_voting_place).first.children.text.strip,
			'voting_place_adress' => html.xpath(@xpath_voting_place_adress).first.children.text.strip,
			'vocal_condition' => html.xpath(@xpath_vocal_condition).first.text.strip,
			'scrutineer_condition' => html.xpath(@xpath_scrutineer_condition).first.text.strip
		}
	end

	def save info
		#if !info.nil?
		#	file = File.open(@file_name, 'a')
		#	file.write(info)
		#	file.write("/n")
		#	file.close()
		#end
		p info
	end

	def verificador t
	        v=1
	        s=0
	        for i in (2..9)
	                if i == 8
	                	v=2
	                else v+=1
	        	end
	        	s+=v*(t%10)
	        	t/=10
	        end
	        s = 11 - s%11
	        if s == 11
	        	return 0.to_s
	        elsif s == 10
	        	return "K"
	        else
	        	return s.to_s
	        end
	end
end

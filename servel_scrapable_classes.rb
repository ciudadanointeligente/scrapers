# coding: utf-8
require './scrapable_classes'
require 'active_record'

ActiveRecord::Base.pluralize_table_names = false

class Municipales2012_comuna < ActiveRecord::Base
	#cambiar el plural de municipales2012?_comuna
end

class ServelDB < StorageableInfo

	def initialize(max, min)
        super()
        @location = 'http://www.elecciones.gov.cl/mobile/alcaldesMobile.action'
        ActiveRecord::Base.establish_connection(
            :adapter => "mysql",
            :host => "localhost",
            :database => "asdasdasd",
			:username => "asdasd",
			:password => "asdasdasdasd"
                )
	end

	def format info
		formatted_info = {}
		info.each do |nombre, codigos|
			codigo_region = codigos[0]
			codigo_comuna = codigos[1]
			formatted_info[nombre] = 'codigoRegion='+codigo_region+'&codigoComuna='+codigo_comuna
		end
		formatted_info
	end

	def get_info doc
		html = Nokogiri::HTML(doc, nil, 'utf-8')
		#get data with xpath
		parsed_data = {}
		comunas = html.css('ul[@data-role] li')
		#"div.ui-btn-text a.ui-link-inherit"
		comunas.each do |comuna|
			regexp_region = /codigoRegion.value = (\d+);/
			regexp_comuna = /codigoComuna.value = (\d+);/
			onclick = comuna.children[0]['onclick']
			codigo_region = onclick.scan(regexp_region)[0][0]
			codigo_comuna = onclick.scan(regexp_comuna)[0][0]
			nombre_comuna = comuna.text.strip
			parsed_data[nombre_comuna] = [codigo_region, codigo_comuna]
		end
		parsed_data
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
end

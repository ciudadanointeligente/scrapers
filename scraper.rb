require 'rubygems'
require 'scraperwiki'
require 'httparty'
require 'libxml'
require 'open-uri'
require 'json'
require 'i18n'

# Scrapable classes
module RestfulApiMethods

  def format info
    info
  end

  def put record
  end

  def post record
  end
end

class GenericStorage
  include RestfulApiMethods

  def save record
    post record
  end

  def post_to_morph record
    # Save in morph.io
    if ((ScraperWiki.select("* from data where `uid`='#{record['uid']}'").empty?) rescue true)
      ScraperWiki.save_sqlite(['uid'], record)
      puts "Adds record for " + record['bill_id']
    else
      puts "Skipping already saved record " + record['uid']
    end
  end

  def post record
    puts "Adds record for " + record['bill_id']
    HTTParty.post(@middleware, {:body => record.to_json, :headers => { 'Content-Type' => 'application/json' } })
  end

  def debug record
    puts '<-----debug-----'
    p record
    puts '------debug---/>'
  end
end

# The real thing
# class VotingHighChamber < GenericStorage
#   def initialize()
#     super()
#     @chamber = 'Senado'
#     @location = 'http://opendata.camara.cl/wscamaradiputados.asmx/Votaciones_Boletin?prmBoletin='
#     @billit_current_location = 'http://billit.ciudadanointeligente.org/bills/search.json?per_page=200&fields=uid'
#   end
# end

class VotingLowChamber < GenericStorage
  def initialize()
    super()
    @chamber = 'C.Diputados'
    @middleware = 'http://middleware.congresoabierto.cl/votes'
    @location = 'http://opendata.camara.cl/wscamaradiputados.asmx/Votaciones_Boletin?prmBoletin='
    @billit_current_location = 'http://billit.ciudadanointeligente.org/bills/search.json?fields=uid&per_page=200'
  end

  def run
    while !@billit_current_location.nil? do
      process
    end
  end

  def process
    @response = HTTParty.get(@billit_current_location, :content_type => :json)
    @response = JSON.parse(@response.body)

    puts "Processing page " + @response['current_page'].to_s + " of " + @response['total_pages'].to_s

    # process a single bill
    @response['bills'].each do |bill|
      process_by_bill bill['uid']
    end

    # obtain the next set of bills if exist
    if @response['links'][1]['rel'] == 'next'
      @billit_current_location = @response['links'][1]['href']
      process
    else
      @billit_current_location = nil
    end
  end

  def process_by_bill bill_id
    sleep 1
    response_voting = HTTParty.get(@location + bill_id, :content_type => :xml)
    response_voting = response_voting['Votaciones']

    if response_voting.nil?
      puts "Skip " + bill_id
    else
      if response_voting['Votacion'].is_a? Array
        response_voting['Votacion'].each do |voting|
          record = get_info voting
          post record
          # debug record  #DEBUG
        end
      else
        record = get_info response_voting['Votacion']
        post record
        # debug record  #DEBUG
      end
    end
  end

  def get_info voting
    record = {
      'uid' => voting['ID'],
      'chamber' => @chamber,
      'date' => voting['Fecha'],
      'type_content' => voting['Tipo']['__content__'],
      'type_code' => voting['Tipo']['Codigo'],
      'result_content' => voting['Resultado']['__content__'],
      'result_code' => voting['Resultado']['Codigo'],
      'quorum_content' => voting['Quorum']['__content__'],
      'quorum_code' => voting['Quorum']['Codigo'],
      'session_id' => voting['Sesion']['ID'],
      'session_number' => voting['Sesion']['Numero'],
      'session_date' => voting['Sesion']['Fecha'],
      'session_type_content' => voting['Sesion']['Tipo']['__content__'],
      'session_type_code' => voting['Sesion']['Tipo']['Codigo'],
      'bill_id' => voting['Boletin'],
      'article' => if voting['Articulo'].nil? then '' else voting['Articulo'] end,
      'procedure_content' => if voting['Tramite'].nil? then '' else voting['Tramite']['__content__'] end,
      'procedure_code' => if voting['Tramite'].nil? then '' else voting['Tramite']['Codigo'] end,
      'report_content' => if voting['Informe'].nil? then '' else voting['Informe']['__content__'] end,
      'report_code' => if voting['Informe'].nil? then '' else voting['Informe']['Codigo'] end,
      'total_affirmative' => voting['TotalAfirmativos'],
      'total_negative' => voting['TotalNegativos'],
      'total_abstentions' => voting['TotalAbstenciones'],
      'total_dispensed' => voting['TotalDispensados'],
      'date_scraped' => Date.today.to_s
    }
    return record
  end
end

# Runner
VotingLowChamber.new.run
# VotingHighChamber.new.run

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
      puts "Adds record " + record['uid'] + " for " + record['bill_id']
    else
      puts "Skipping already saved record " + record['uid']
    end
  end

  def post record
    HTTParty.post(@middleware, {:body => record.to_json, :headers => { 'Content-Type' => 'application/json' } })
    puts "Adds record " + record['uid'] + " for " + record['bill_id']
  end

  def debug record
    puts '<-----debug-----'
    p record
    puts '------debug---/>'
  end
end

# The real thing
class VotingLowChamber < GenericStorage
  def initialize()
    super()
    @chamber = 'C.Diputados'
    @location_vote_general = 'http://opendata.camara.cl/wscamaradiputados.asmx/getVotaciones_Boletin?prmBoletin='
    @location_vote_detail = 'http://opendata.camara.cl/wscamaradiputados.asmx/getVotacion_Detalle?prmVotacionID='
    @middleware = 'http://middleware.congresoabierto.cl/votes'
    @billit_current_location = 'http://billit.ciudadanointeligente.org/bills/search.json?fields=uid&per_page=100'
  end

  def process
    while !@billit_current_location.nil? do
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
      else
        @billit_current_location = nil
      end
    end
  end

  def get_details_of_voting voting_id
    response = HTTParty.get(@location_vote_detail + voting_id, :content_type => :xml)
    response_votes = response['Votacion']['Votos']['Voto']
    response_pair_up = response['Votacion']['Pareos']['Pareo']
    
    @votes = Array.new
    response_votes.each do |single_vote|
      vote = Hash.new
      vote['uid'] = single_vote['Diputado']['DIPID']
      vote['lastname'] = single_vote['Diputado']['Nombre']
      vote['parental_surname'] = single_vote['Diputado']['Apellido_Paterno']
      vote['maternal_surname'] = single_vote['Diputado']['Apellido_Materno']
      vote['option_content'] = single_vote['Opcion']['__content__']
      vote['option_code'] = single_vote['Opcion']['Codigo']
      @votes << vote
    end

    @pair_ups = Array.new
    response_pair_up.each do |single_pair_up|
      pair_up = Hash.new
      pair_up['congressman1'] = Hash.new
      pair_up['congressman1']['uid'] = single_pair_up['Diputado1']['DIPID']
      pair_up['congressman1']['lastname'] = single_pair_up['Diputado1']['Nombre']
      pair_up['congressman1']['parental_surname'] = single_pair_up['Diputado1']['Apellido_Paterno']
      pair_up['congressman1']['maternal_surname'] = single_pair_up['Diputado1']['Apellido_Materno']
      pair_up['congressman2'] = Hash.new
      pair_up['congressman2']['uid'] = single_pair_up['Diputado2']['DIPID']
      pair_up['congressman2']['lastname'] = single_pair_up['Diputado2']['Nombre']
      pair_up['congressman2']['parental_surname'] = single_pair_up['Diputado2']['Apellido_Paterno']
      pair_up['congressman2']['maternal_surname'] = single_pair_up['Diputado2']['Apellido_Materno']
      @pair_ups << pair_up
    end
  end

  def process_by_bill bill_id
    sleep 1
    response_voting = HTTParty.get(@location_vote_general + bill_id, :content_type => :xml)
    response_voting = response_voting['Votaciones']

    if response_voting.nil?
      puts "Skip " + bill_id
    else
      if response_voting['Votacion'].is_a? Array
        response_voting['Votacion'].each do |voting|
          get_details_of_voting voting['ID']
          record = get_info voting, @votes, @pair_ups
          post record
          # debug record  #DEBUG
        end
      else
        get_details_of_voting response_voting['Votacion']['ID']
        record = get_info response_voting['Votacion'], @votes, @pair_ups
        post record
        # debug record  #DEBUG
      end
    end
  end

  def get_info voting, votes, pair_ups
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
      'votes' => votes,
      'pair_ups' => pair_ups,
      'date_scraped' => Date.today.to_s
    }
    return record
  end
end

class VotingMassStorage < GenericStorage
  def initialize()
    super()
    @middleware = 'http://middleware.congresoabierto.cl/votes.json'
  end

  def process
    @response = HTTParty.get(@middleware, :content_type => :json)
    @response = JSON.parse(@response.body)

    @response.each do |voting|
      record = get_info voting
      post_to_morph record
    end
  end

  def get_info voting
    record = {
      'uid' => voting['uid'],
      'chamber' => voting['chamber'],
      'date' => voting['date'],
      'type_content' => voting['type_content'],
      'type_code' => voting['type_code'],
      'result_content' => voting['result_content'],
      'result_code' => voting['result_code'],
      'quorum_content' => voting['quorum_content'],
      'quorum_code' => voting['quorum_code'],
      'session_id' => voting['session_id'],
      'session_number' => voting['session_number'],
      'session_date' => voting['session_date'],
      'session_type_content' => voting['session_type_content'],
      'session_type_code' => voting['session_type_code'],
      'bill_id' => voting['bill_id'],
      'article' => if voting['article'].nil? then '' else voting['article'].tr("\n","") end,
      'procedure_content' => if voting['procedure_content'].nil? then '' else voting['procedure_content'] end,
      'procedure_code' => if voting['procedure_code'].nil? then '' else voting['procedure_code'] end,
      'report_content' => if voting['report_content'].nil? then '' else voting['report_content'] end,
      'report_code' => if voting['report_code'].nil? then '' else voting['report_code'] end,
      'total_affirmative' => voting['total_affirmative'],
      'total_negative' => voting['total_negative'],
      'total_abstentions' => voting['total_abstentions'],
      'total_dispensed' => voting['total_dispensed'],
      'date_scraped' => Date.today.to_s
    }
    return record
  end
end

# Runner
# VotingMassStorage.new.process # Store the values into a middleware service of ciudadano inteligente
VotingLowChamber.new.process  # The real scraper, but in morph.io it doesn't work because a memory allocation bug in ruby 1.9.3

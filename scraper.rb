require 'rubygems'
require 'httparty'
require 'json'
require 'byebug'
require 'billit_representers/models/bill_update'
require 'billit_representers/models/motion'
require 'libxml'
require 'open-uri'

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

  def post record
    f = File.open('post_errors.log', 'a')
    begin
      bill = Billit::BillUpdate.get @billit + @bill_id, 'application/json'
      bill.motions = [] if bill.motions.nil?
      bill.motions << record
      bill.put @billit + @bill_id, 'application/json'
      puts "adds record for " + @bill_id
    rescue Exception=>e
      f.puts @bill_id
      puts e
    end
  end

  def debug record
    puts '<----- debug -----'
    puts record.text + " of bill " + @bill_id
    puts '------ debug ---/>'
  end
end

# The real thing
class VotingLowChamber < GenericStorage
  def initialize()
    super()
    @chamber = 'C.Diputados'
    @location_vote_general = 'http://opendata.camara.cl/wscamaradiputados.asmx/getVotaciones_Boletin?prmBoletin='
    @location_vote_detail = 'http://opendata.camara.cl/wscamaradiputados.asmx/getVotacion_Detalle?prmVotacionID='
    # @billit_current_location = 'http://billit.ciudadanointeligente.org/bills/search.json?fields=uid&per_page=200'
    @billit_current_location = 'http://billit.ciudadanointeligente.org/bills/search.json?fields=uid&page=25&per_page=50'
    @billit = 'http://billit.ciudadanointeligente.org/bills/'
    @bill_id = String.new
  end

  def process
    while !@billit_current_location.nil? do
      @response = HTTParty.get(@billit_current_location, :content_type => :json)
      @response = JSON.parse(@response.body)

      puts "*************** Processing page " + @response['current_page'].to_s + " of " + @response['total_pages'].to_s + " ***************"

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
    response_pair_up = if response['Votacion']['Pareos'].nil? then nil else response['Votacion']['Pareos']['Pareo'] end
    @votes = Array.new
    response_votes.each do |single_vote|
      vote = Hash.new
      vote['voter_id'] = single_vote['Diputado']['Apellido_Paterno'] + " " + single_vote['Diputado']['Apellido_Materno'] + ", " + single_vote['Diputado']['Nombre']
      case single_vote['Opcion']['Codigo']
      when '0' #Negativo
        vote['option'] = "NO"
      when '1' #Afirmativo
        vote['option'] = "SI"
      when '2' #Abstencion
        vote['option'] = "ABSTENCION"
      else
        vote['option'] = "Sin información"
      end
      @votes << vote
    end

    if !response_pair_up.nil?
      if response_pair_up.is_a? Array
        @pair_ups = Array.new
        i = 1
        response_pair_up.each do |single_pair_up|
          # first pair
          pair_up1 = Hash.new
          pair_up1['voter_id'] = single_pair_up['Diputado1']['Apellido_Paterno'] + " " + single_pair_up['Diputado1']['Apellido_Materno'] + ", " + single_pair_up['Diputado1']['Nombre']
          pair_up1['option'] = "PAREO " + i.to_s #paired
          @pair_ups << pair_up1

          # second pair
          pair_up2 = Hash.new
          pair_up2['voter_id'] = single_pair_up['Diputado2']['Apellido_Paterno'] + " " + single_pair_up['Diputado2']['Apellido_Materno'] + ", " + single_pair_up['Diputado2']['Nombre']
          pair_up2['option'] = "PAREO " + i.to_s
          @pair_ups << pair_up2
          i = i + 1
        end
      else
        single_pair_up = response_pair_up
        @pair_ups = Array.new
        i = 1
        # first pair
        pair_up1 = Hash.new
        pair_up1['voter_id'] = single_pair_up['Diputado1']['Apellido_Paterno'] + " " + single_pair_up['Diputado1']['Apellido_Materno'] + ", " + single_pair_up['Diputado1']['Nombre']
        pair_up1['option'] = "PAREO " + i.to_s #paired
        @pair_ups << pair_up1

        # second pair
        pair_up2 = Hash.new
        pair_up2['voter_id'] = single_pair_up['Diputado2']['Apellido_Paterno'] + " " + single_pair_up['Diputado2']['Apellido_Materno'] + ", " + single_pair_up['Diputado2']['Nombre']
        pair_up2['option'] = "PAREO " + i.to_s
        @pair_ups << pair_up2
      end
    end
  end

  def process_by_bill bill_id
    f = File.open('errors.log', 'a')
    sleep 2
    begin
      response_voting = HTTParty.get(@location_vote_general + bill_id, :content_type => :xml)
      response_voting = response_voting['Votaciones']

      if response_voting.nil?
        puts "skip " + bill_id
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
    rescue Exception=>e
      f.puts bill_id
      puts e
    end
  end

  def get_info voting, votes, pair_ups
    @bill_id = voting['Boletin']

    motion = BillitMotion.new
    motion.organization = @chamber
    motion.date = voting['Fecha']
    motion.text = if voting['Articulo'].nil? then 'Sin título' else voting['Articulo'].strip end
    motion.requirement = voting['Quorum']['__content__']
    motion.result = voting['Resultado']['__content__']
    motion.session = voting['Sesion']['ID']
    motion.vote_events = []

    vote_event = BillitVoteEvent.new
    #Counts
    vote_event.counts = []
    count = BillitCount.new
    count.option = "SI"
    count.value = voting['TotalAfirmativos'].to_i
    vote_event.counts << count

    count = BillitCount.new
    count.option = "NO"
    count.value = voting['TotalNegativos'].to_i
    vote_event.counts << count

    count = BillitCount.new
    count.option = "ABSTENCION"
    count.value = voting['TotalAbstenciones'].to_i
    vote_event.counts << count

    count = BillitCount.new
    count.option = "PAREO"
    count.value = pair_ups.count
    vote_event.counts << count

    #Votes
    vote_event.votes = []
    votes_array = votes + pair_ups
    votes_array.each do |single_vote|
      vote = BillitVote.new
      vote.voter_id = single_vote["voter_id"]
      vote.option = single_vote["option"]
      vote_event.votes << vote
    end
    motion.vote_events << vote_event
    return motion
  end
end

# Runner
if ARGV.empty?
  puts "initialize the full mode (all the bills)"
  VotingLowChamber.new.process
else
  ARGV.each do |id|
    puts "initialize motion per bill #{id}"
    VotingLowChamber.new.process_by_bill id
  end
end

require 'rubygems'
require 'httparty'
require 'libxml'
require 'open-uri'
require 'json'

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
    motions = HTTParty.get(@billit + @bill_id + '.json', :content_type => :json)
    motions = JSON.parse(motions.body)['motions']
    motions << record

    HTTParty.post(@billit + @bill_id + '.json', body: {motions: motions})
    puts "adds record for " + @bill_id
  end

  def debug record
    puts '<-----debug-----'
    puts @bill_id
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
    @billit_current_location = 'http://billit.ciudadanointeligente.org/bills/search.json?fields=uid&per_page=100'
    @billit = 'http://billit.ciudadanointeligente.org/bills/'
    @bill_id = String.new
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
    response_pair_up = if response['Votacion']['Pareos'].nil? then nil else response['Votacion']['Pareos']['Pareo'] end
    @votes = Array.new
    response_votes.each do |single_vote|
      vote = Hash.new
      vote['voter_id'] = single_vote['Diputado']['Apellido_Paterno'] + " " + single_vote['Diputado']['Apellido_Materno'] + ", " + single_vote['Diputado']['Nombre']
      case single_vote['Opcion']['Codigo']
      when '0' #Negativo
        vote['option'] = "NO" #no
      when '1' #Afirmativo
        vote['option'] = "SI" #yes
      when '2' #Abstencion
        vote['option'] = "ABSTENCION" #abstain
      else
        vote['option'] = ""
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
    sleep 1
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
  end

  def get_info voting, votes, pair_ups
    @bill_id = voting['Boletin']

    vote_events = [
      {
        'counts' => [
          {
            'option' => "yes",
            'value' => voting['TotalAfirmativos'].to_i
          },
          {
            'option' => "no",
            'value' => voting['TotalNegativos'].to_i
          },
          {
            'option' => "abstain",
            'value' => voting['TotalAbstenciones'].to_i
          },
          {
            'option' => "paired",
            'value' => pair_ups.count
          }
        ],
        'votes' => votes + pair_ups #all votes, from options yes, no and abstain + paired
      }
    ]

    # motion
    record = {
      'organization' => @chamber,
      'text' => if voting['Articulo'].nil? then '' else voting['Articulo'] end,
      'date' => voting['Fecha'],
      'requirement' => voting['Quorum']['__content__'],
      'result' => voting['Resultado']['__content__'],
      'session' => voting['Sesion']['ID'],
      'vote_events' => vote_events
    }
    return record
  end
end

# Runner
VotingLowChamber.new.process

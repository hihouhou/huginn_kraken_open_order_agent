module Agents
  class KrakenOpenOrderAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The Kraken OpenOrders agent fetches open orders from Kraken.

      `debug` is used to verbose mode.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "refid": null,
          "userref": 0,
          "status": "open",
          "opentm": 1590488127.3594,
          "starttm": 0,
          "expiretm": 0,
          "descr": {
            "pair": "XBTEUR",
            "type": "buy",
            "ordertype": "limit",
            "price": "1.0",
            "price2": "0",
            "leverage": "none",
            "order": "buy 1000000 XBTEUR @ limit 1.0",
            "close": ""
          },
          "vol": "1000000",
          "vol_exec": "0.00000000",
          "cost": "0.00000",
          "fee": "0.00000",
          "price": "0.00000",
          "stopprice": "0.00000",
          "limitprice": "0.00000",
          "misc": "",
          "oflags": "fciq"
        }
    MD

    def default_options
      {
        'apikey' => '',
        'privatekey' => '',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :apikey, type: :string
    form_configurable :privatekey, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options
      unless options['apikey'].present?
        errors.add(:base, "apikey is a required field")
      end

      unless options['privatekey'].present?
        errors.add(:base, "privatekey is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      post_private
    end

    private
    
    # Generate a continually-increasing unsigned 51-bit integer nonce from the
    # current Unix Time.
    #
    def generate_nonce
# doesn't work....
#      (Time.now.to_f * 1_000_000).to_i
      `date +%s%N`.to_i
    end

    def post_private(opts = {})
      url = "https://api.kraken.com/0/private/OpenOrders"
      nonce = opts['nonce'] = generate_nonce
      params = opts.map { |param| param.join('=') }.join('&')
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["Api-Key"] = interpolated['apikey']
      request["Api-Sign"] = authenticate(auth_url(nonce, params))
      request.set_form_data(
        "nonce" => nonce,
      )
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request  status : #{response.code}"

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end

      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log "payload"
        log payload
      end

      if interpolated['changes_only'] == 'true'
        if payload['result']['open'].to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['result']['open'].each do | k, v|
                  log v
                  create_event payload: v
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload['result']['open'].each do | k, v |
              found = false
              last_status.each do | kbis, vbis|
                if k == kbis
                  found = true
                end
              end
              if interpolated['debug'] == 'true'
                log "found is #{found}"
              end
              if found == false
                create_event payload: v
              end
            end
          end
          memory['last_status'] = payload['result']['open'].to_s
        end
      else
        create_event payload: payload['result']['open']
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload['result']['open'].to_s
        end
      end
    end



    def auth_url(nonce, params)
      data = "#{nonce}#{params}"
      "/0/private/OpenOrders" + Digest::SHA256.digest(data)
    end

    def authenticate(url)
      hmac = OpenSSL::HMAC.digest('sha512', Base64.decode64(interpolated['privatekey']), url)
      Base64.strict_encode64(hmac)
    end
  end
end

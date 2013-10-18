require 'net/http' if RUBY_VERSION < '2'

module HasOffersV3
  class Base
    class << self
      def get_request(target, method, params, &block)
        if block.nil?
          make_request(:get, target, method, params)
        else
          page = 1
          begin
            response = make_request(:get, target, method, params.merge(page: page))
            block.call response
            page += 1
          end until page > (response.page_info['page_count'] || 1)
        end
      end

      def post_request(target, method, params, &block)
        if block.nil?
          make_request(:post, target, method, params)
        else
          page = 1
          begin
            response = make_request(:post, target, method, params.merge(page: page))
            block.call response
            page += 1
          end until page > (response.page_info['page_count'] || 1)
        end
      end

      def requires!(hash, required_params)
        missing_params = []
        required_params.each do |param|
          missing_params.push param unless hash.has_key?(param)
        end
        unless missing_params.empty?
          raise ArgumentError.new("Missing required parameter(s): #{missing_params.join(', ')}")
        end
      end

    private

      def new_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 600
        http
      end

      def query_string(data_hash)
        # Rails to_params adds an extra open close brackets to multi-dimensional array parameters which
        # hasoffers doesn't like, so the gsub here takes care of that.
        data_hash.to_param.gsub(/\[\]\[/,'[')
      end

      def make_request(http_method, target, method, params)
        data = build_request_params(method, params)
        if http_method == :post
          uri               = URI.parse("#{HasOffersV3.configuration.base_uri}/#{target}.json")
          http              = new_http(uri)
          raw_request       = Net::HTTP::Post.new(uri.request_uri)
          raw_request.body  = query_string data
        else # assume get
          uri               = URI.parse("#{HasOffersV3.configuration.base_uri}/#{target}.json?#{query_string(data)}")
          http              = new_http(uri)
          raw_request       = Net::HTTP::Get.new(uri.request_uri)
        end
        http_response = execute_request(http, raw_request)

        Response.new(http_response)
      end

      def execute_request(net_http, raw_request)
        if defined?(Rails) && Rails.env.test? && !stubbed_reqest?
          response = Net::HTTPOK.new '1.1', '200', 'OK'
          response.stub(:body) { '{"response":{"status":1,"data":[]}}' }
          response
        else
          net_http.request raw_request
        end
      end

      def build_request_params(method, params)
        params['Method'] = method
        params.merge NetworkId: HasOffersV3.configuration.network_id, NetworkToken: HasOffersV3.configuration.api_key
      end

      # Check if there was stub for request
      def stubbed_reqest?
        defined?(WebMock) &&
          (request_signature = WebMock::RequestSignature.new(:any, /.*api\.hasoffers\.com.*/)) &&
          !!WebMock.registered_request?(request_signature)
      end
    end
  end
end

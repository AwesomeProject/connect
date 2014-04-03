require 'net/http'
require 'suse/toolkit/utilities'

module SUSE
  module Connect
    # Client to interact with API
    class Client

      DEFAULT_URL = 'https://scc.suse.com'
      include SUSE::Toolkit::Utilities

      attr_reader :options, :url, :api

      def initialize(opts)
        @options            = {}
        @options[:token]    = opts[:token]
        @options[:insecure] = !!opts[:insecure]
        @options[:debug]    = !!opts[:verbose]
        @url                = opts[:url] || DEFAULT_URL
        @api                = Api.new(self)
      end

      def register!
        announce_system unless System.registered?
        activate_product Zypper.base_product
      end

      def announce_system
        result = @api.announce_system(token_auth(@options[:token])).body
        Zypper.write_base_credentials(result['login'], result['password'])
      end

      def activate_product(product_ident)
        result = @api.activate_product(basic_auth, product_ident).body
        System.add_service(
          Service.new(result['sources'], result['enabled'], result['norefresh'])
        )
      end

      # @param product [Hash] product to query extensions for
      def list_products(product_ident)
        result = @api.addons(basic_auth, product_ident).body
        result.map do |product|
          SUSE::Connect::Product.new(product['name'], '', '', product['zypper_name'])
        end
      end

    end
  end
end

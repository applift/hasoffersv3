class HasOffersV3
  class Application < Base
    class << self
      def get_payout_tiers(params = {})
        get_request 'findAllAffiliateTiers', params
      end
    end
  end
end

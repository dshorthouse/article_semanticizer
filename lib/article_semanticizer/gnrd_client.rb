module ArticleSemanticizer
  class GnrdClient

    def initialize(gnrd_api_url, gnrd_batch_size)
      @url = gnrd_api_url
      @batch_size = gnrd_batch_size
    end

  end
end


module ArticleSemanticizer
  class Carousel
    include Enumerable
    attr_accessor :herd_size, :carousel_ary

    alias :size :count

    def initialize(type = 'text')
      @herd_size = ArticleSemanticizer::Config.carousel_size
      @carousel_ary = []
      @cursor = 0
      @first_batch = true
      @content_type = type
    end
    
    def rebuild_names_hash
      if Article::NAMES_HASH.empty?
        NameString.all.each do |n|
          Article::NAMES_HASH[n.name] = n.id
        end
      end
    end

    def populate
      if @first_batch
        Article.connection.execute("UPDATE articles SET gnrd_url = null WHERE status = %s" % Article::STATUS[:failed])
        Article.connection.execute("UPDATE articles SET status = %s WHERE status != %s" % [Article::STATUS[:init], Article::STATUS[:completed]])
        @first_batch = false
      end
      articles = Article.where(:status => Article::STATUS[:init]).limit(@herd_size - @carousel_ary.size)
      articles.each do |a|
        a.status = Article::STATUS[:enqueued]
        a.save!
      end
      @carousel_ary = articles + @carousel_ary
    end

    def send_content
      @cursor = 0
      @carousel_ary.each_with_index do |a, i|
        if a.gnrd_url
          @cursor = i
          break
        end
        a.send_content(@content_type)
      end
    end

    def get_names
      @carousel_ary = @carousel_ary[@cursor..-1] + @carousel_ary[0...@cursor] if @cursor != 0
      @herd_size.times do
        article = @carousel_ary.shift
        if article && article.status != Article::STATUS[:failed]
          article.get_names
          article.names ? article.names_to_content : @carousel_ary.push(article)
        end
      end
      @cursor = 0
    end

    def each &block
      @carousel_ary.each { |horsie| block.call(horsie) }
    end

  end
end

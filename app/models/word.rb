class Word < ActiveRecord::Base
  extend SearchConcern

  has_and_belongs_to_many :word_sets

  has_many :definitions, dependent: :delete_all

  auto_strip_attributes :text, nullify: true, squish: true

  # validate :text, presence: true
  validates_presence_of :text


  module ClassMethods
    def search_for(string, type="include")
      where("text ILIKE ?", ilike_string(string, type))
    end

    def self_or_new word_or_string
      word_or_string.is_a?(Word) ?
        word_or_string :
        create(text: word_or_string)
    end

    def destroy_unlinked
      find_unlinked.destroy_all
    end

    def find_unlinked
      where("words.id NOT IN(
        SELECT words.id FROM words INNER JOIN word_sets_words ON words.id = word_sets_words.word_id
      )")
    end

  end
  extend ClassMethods

  def display
    (display_text || text).to_s
  end

  def describe_match_type(query=nil)
    query ||= WordSet.current_query
    
    if self.text.downcase == query
      "exact"
    elsif current_query_index_of_text == 0
      "begin"
    elsif !current_query_index_of_text.nil?
      "include"
    else
      "none"
    end
  end

  def matches_current_query? options={}
    if options[:exact]
      self.text.downcase == WordSet.current_query
    elsif WordSet.current_query_type == "begin"
      current_query_index_of_text == 0
    else
      !current_query_index_of_text.nil?
    end
  end

  def current_query_index_of_text
    @current_query_index_of_text ||= self.text.downcase.index(WordSet.current_query)
  end

  def definition
    @definition ||= get_definitions.first
  end

  def get_definitions
    defs = definitions.all

    return defs if no_definitions?

    apply_wordnik_definitions if defs.count.zero?

    definitions
  end

  # comparator
  def <=>(another)
    text.downcase <=> another.text.downcase
  end
  

  protected


  def apply_wordnik_definitions
    wordnik_definitions.each do |row|
      definition = Definition.build_from_wordnik(row).tap do |d|
        d.word_id = self.id
        d.save!
      end
      definitions << definition
    end if wordnik_definitions
    definitions
  end

  def wordnik_definitions
    return @wordnik_definitions if @wordnik_definitions

    @wordnik_definitions = Wordnik.word.get_definitions(self.text)
    @wordnik_definitions = @wordnik_definitions.blank? ? [] : @wordnik_definitions
  end


  private


  # delete all definitions in case the word was changed
  after_save :delete_definitions
  def delete_definitions
    definitions.delete_all
    true
  end


end

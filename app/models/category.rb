class Category < ActiveRecord::Base
  acts_as_list
  has_and_belongs_to_many :articles, :order => "created_at DESC"
  
  def self.find_all_with_article_counters
    self.find_by_sql(%{
      SELECT id, name, permalink, position, COUNT(article_id) AS article_counter
      FROM #{Category.table_name} categories LEFT OUTER JOIN #{Category.table_name_prefix}articles_categories#{Category.table_name_suffix} articles_categories 
        ON articles_categories.category_id = categories.id
      GROUP BY categories.id, categories.name, categories.position, categories.permalink
      ORDER BY position
      })
  end
  
  def stripped_name
    self.name.to_url
  end
  
  def self.reorder(serialized_list)
    self.transaction do
      serialized_list.each_with_index do |cid,index|
        find(cid).update_attribute "position", index rescue nil
      end
    end
  end
  
  def self.reorder_alpha
    reorder find(:all, :order => :name).collect { |c| c.id }
  end

  protected  
  
  before_save :set_defaults
  
  def set_defaults
    self.permalink ||= self.stripped_name
  end
  
  validates_presence_of :name
  validates_uniqueness_of :name, :on => :create
end


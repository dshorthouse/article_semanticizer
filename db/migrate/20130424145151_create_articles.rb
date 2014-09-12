class CreateArticles < ActiveRecord::Migration
  def change
    create_table :articles do |t|
      t.string  :pdf_path
      t.string  :text_path
      t.string  :metadata_path
      t.integer :year
      t.string  :title
      t.text    :citation
      t.text    :abstract
      t.string  :doi
      t.string  :gnrd_url
      t.integer :status, :default => 0
      t.timestamps
    end
    add_index :articles, :status
  end
end
    
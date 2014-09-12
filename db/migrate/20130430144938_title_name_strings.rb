class TitleNameStrings < ActiveRecord::Migration
  def up
    execute "CREATE TABLE `title_name_strings` (
      `article_id` int(11) NOT NULL,
      `name_string_id` int(11) NOT NULL,
      `name_offset_start` int(11) NOT NULL,
      `name_offset_end` int(11) NOT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`article_id`,`name_string_id`, `name_offset_start`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
  end

  def down
    drop_table :article_name_strings
  end
end
    
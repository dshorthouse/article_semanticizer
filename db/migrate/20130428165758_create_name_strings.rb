class CreateNameStrings < ActiveRecord::Migration
  def up
    execute "CREATE TABLE `name_strings` (
      `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
      `name` varchar(255) COLLATE utf8_bin DEFAULT NULL,
      `status` tinyint DEFAULT 0,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `idx_name_strings_1` (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
  end

  def down
    drop_table :name_strings
  end
end
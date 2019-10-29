class OpenApiConstraint
  PRODUCTS = Dir.glob("#{Rails.application.config.oas_path}/**/*.yml").map do |file|
    next if file.starts_with?("#{Rails.application.config.oas_path}/common/")
    file.sub("#{Rails.application.config.oas_path}/", '').chomp('.yml')
  end.compact.freeze

  def self.list
    PRODUCTS
  end

  def self.products
    { definition: Regexp.new("^(#{PRODUCTS.join('|')})$") }
  end

  def self.errors_available
    all = PRODUCTS.dup.concat(['application'])
    { definition: Regexp.new(all.join('|')) }
  end

  def self.products_with_code_language
    products.merge(CodeLanguage.route_constraint)
  end

  def self.match?(definition, code_language = nil)
    if code_language.nil?
      products_with_code_language[:definition].match?(definition)
    else
      products_with_code_language[:definition].match?(definition) &&
        products_with_code_language[:code_language].match?(code_language)
    end
  end
end

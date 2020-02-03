class Tutorial
  include ActiveModel::Model
  attr_accessor :raw, :name, :current_step, :current_product,
                :title, :description, :products, :subtasks,
                :prerequisites, :code_language, :available_languages

  def content_for(step_name)
    if ['introduction', 'conclusion'].include? step_name
      raise "Invalid step: #{step_name}" unless raw[step_name]

      return raw[step_name]['content']
    end

    path = DocFinder.find(
      root: self.class.task_content_path,
      document: step_name,
      language: I18n.locale,
      code_language: code_language
    )

    File.read(path)
  end

  def first_step
    subtasks.first['path']
  end

  def prerequisite?
    prerequisites.pluck('path').include?(@current_step)
  end

  def next_step
    current_task_index = subtasks.pluck('path').index(@current_step)
    return nil unless current_task_index

    subtasks[current_task_index + 1]
  end

  def previous_step
    current_task_index = subtasks.pluck('path').index(@current_step)
    return nil unless current_task_index
    return nil if current_task_index <= 0

    subtasks[current_task_index - 1]
  end

  def self.available_code_languages(path)
    DocFinder.code_languages_for_tutorial(path: path.sub('.yml', '/')).map do |path|
      File.basename(Pathname.new(path).basename, '.yml')
    end
  end

  def self.load(name, current_step, current_product = nil, code_language)
    metadata_path = DocFinder.find(
      root: 'config/tutorials',
      document: name,
      language: I18n.default_locale,
      format: 'yml'
    )
    metadata = YAML.safe_load(File.read(metadata_path))
    current_product ||= metadata['products'].first

    unless code_language
      code_language = available_code_languages(metadata_path)
        .sort_by { |k| CodeLanguage.languages.map(&:key).index(k) }
        .first
    end

    document_path = DocFinder.find(
      root: 'config/tutorials',
      document: name,
      language: I18n.default_locale,
      code_language: code_language,
      format: 'yml'
    )
    config = YAML.safe_load(File.read(document_path))

    Tutorial.new({
      available_languages: available_code_languages(metadata_path),
      raw: config,
      code_language: code_language,
      name: name,
      current_step: current_step,
      current_product: current_product,
      title: metadata['title'],
      description: metadata['description'],
      products: config['products'],
      prerequisites: load_prerequisites(config['prerequisites'], current_step, code_language),
      subtasks: load_subtasks(config['introduction'], config['prerequisites'], config['tasks'], config['conclusion'], current_step, code_language),
    })
  end

  def self.load_prerequisites(prerequisites, current_step, code_language)
    return [] unless prerequisites

    prerequisites.map do |t|
      t_path = DocFinder.find(
        root: task_content_path,
        code_language: code_language,
        document: t,
        language: I18n.locale
      )
      raise "Prerequisite not found: #{t}" unless File.exist? t_path

      content = File.read(t_path)
      prereq = YAML.safe_load(content)
      {
        'path' => t,
        'title' => prereq['title'],
        'description' => prereq['description'],
        'is_active' => t == current_step,
        'content' => content,
      }
    end
  end

  def self.load_subtasks(introduction, prerequisites, tasks, conclusion, current_step, code_language)
    tasks ||= []

    tasks = tasks.map do |t|
      t_path = DocFinder.find(
        root: task_content_path,
        document: t,
        language: I18n.locale,
        code_language: code_language
      )
      raise "Subtask not found: #{t}" unless File.exist? t_path

      subtask_config = YAML.safe_load(File.read(t_path))
      {
        'path' => t,
        'title' => subtask_config['title'],
        'description' => subtask_config['description'],
        'is_active' => t == current_step,
      }
    end

    if prerequisites
      tasks.unshift({
        'path' => 'prerequisites',
        'title' => 'Prerequisites',
        'description' => 'Everything you need to complete this task',
        'is_active' => current_step == 'prerequisites',
      })
    end

    if introduction
      tasks.unshift({
        'path' => 'introduction',
        'title' => introduction['title'],
        'description' => introduction['description'],
        'is_active' => current_step == 'introduction',
      })
    end

    if conclusion
      tasks.push({
        'path' => 'conclusion',
        'title' => conclusion['title'],
        'description' => conclusion['description'],
        'is_active' => current_step == 'conclusion',
      })
    end

    tasks
  end

  def self.task_content_path
    '_tutorials'
  end
end

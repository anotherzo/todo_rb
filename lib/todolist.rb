require "caldav"
require "yaml"

class TodoList
  def initialize(name, config)
    @name = name
    @caldav = Array.new
    config['cals'][name].size.times do |cl|
      @caldav << Caldav.new(config, config['cals'][name][cl])
    end
  end

  def getTodos
    todos = @caldav.map { |c| c.todo }.flatten
    todos.sort { |x,y| x.sortorder <=> y.sortorder }
  end

  def read(all=false)
    getTodos.each_with_index do |t,i|
      puts "#{i}) #{t} #{t.completed?}" if (!t.completed || all)
    end
  end

  def create(summary)
    t = Todo.new
    t.summary = summary
    @caldav[0].createTodo t
  end

  def createFromFile(filename)
    list = YAML.load(File.read(filename))
    list.each { |el| create el }
  end

  def delete(nr)
    if nr == 'done'
      td = getTodos.select { |t| t.completed? }
      td.each do |t|
        @caldav[0].delete t.uid
      end
    else
      nrs = nr.split(',')
      td = getTodos
      nrs.each do |nr|
        uid = td[nr.to_i].uid
        @caldav[0].delete uid
      end
    end
  end
end

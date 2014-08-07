# encoding: UTF-8

$: << Dir.pwd

%w{nokogiri yaml mechanize sinatra/partial }.each { |g| require g }

class Fuamo < Sinatra::Base

  configure do 
    register Sinatra::Partial
    enable :partial_underscores
    BASE_URL = "http://fuamo.rosminzdrav.ru"
    MO = YAML::load_file('mo.yml')
    AUTH = YAML::load_file('login_password.yml')
    @mo = {}
  end
  
  helpers do
    # имеет ли страничка прикрепленный pdf
    def have_pdf? page
      page.search('p.small').empty? ? false : true
    end
    # Весь олгоритм - вставляем ссылку
    def start_parse link 
      is_empty_table_on_page = lambda { |page, options = "table:last td a"| page.search("#{options}").empty? }
      is_over_table_on_page = lambda { |page, index| page.search('table:last td a')[index].nil? }
      href_from_a_in_table = lambda { |page, index| page.search('table:last td a')[index]['href'] }
      text_from_a_in_table = lambda { |page, index, options = "table:last td a"| page.search(options)[index].text }
      get_page_nokogirize = lambda { |page, route, index| Nokogiri::HTML(@agent.get(BASE_URL + href_from_a_in_table.call(page, index)).body) }
      get_page = lambda { |base_url = BASE_URL, route| Nokogiri::HTML(@agent.get(base_url + route).body)}
      get_data_from_edit_label = lambda { |page, label_for_name| page.search("label [@for=#{label_for_name}]").text }
      get_data_from_edit_input = lambda { |page, input_name| page.at(input_name)['value'] }
      get_data_from_edit_input_department = lambda { |page, input_name| page.at(input_name).value }
      element_checked_in_table = lambda { |page, input_name| page.at("input##{input_name}  [@checked=checked]").nil? ? false : true }
      @mo = {}
      @mo['employees'] = []
      @mo['buildings'] = []
      @mo['info'] = []

      #названия лейблов и ид полей ввода информации об МО
      @mo_fields = { 
        'mo_name' => '#mo_name',
        'mo_name_short' => '#mo_name_short',
        'mo_ogrn' => '#mo_ogrn', 
        'mo_ffoms' => '#mo_ffoms', 
        'mo_oid' => '#mo_oid', 
        'mo_city' => '#mo_city', 
        'mo_street' => '#mo_street', 
        'mo_house' => '#mo_house',
        'mo_corpus' => '#mo_corpus', 
        'mo_building' => '#mo_building', 
        'mo_postal_index' => '#mo_postal_index'
      }

      #названия техники и софта для компьютера в помещении
      @list_of_medtechnics = { 
       'Лабораторное оборудование' => { 'room_dev_lab' => 'room_po_dev_lab' }, 
       'Маммографический аппарат' => { 'room_dev_mammograf' => 'room_po_dev_mammograf' }, 
       'Аппарат МРТ' => { 'room_dev_mrt' => 'room_po_dev_mrt' }, 
       'Аппарат КТ' => { 'room_dev_kt' => 'room_po_dev_kt' }, 
       'Рентген' => { 'room_dev_rentgen' => 'room_po_dev_rentgen' }, 
       'Эндоскопическое оборудование' => { 'room_dev_endoscope' => 'room_po_dev_endoscope' }
      }

      @agent = Mechanize.new
      page = @agent.get('http://fuamo.rosminzdrav.ru/users/sign_in')
      form = page.form
      form['user[email]'] = AUTH['username']
      form['user[password]'] = AUTH['password']
      page = @agent.submit(form)

      mos = link
      mos_edit = mos + "/edit"

      main_page_edit = @agent.get(mos_edit)

      @mo_main_page_edit = get_page.call('', mos_edit)
      @main_page = get_page.call('', mos)

      # заполнение информации об МО
      @mo_fields.each do |k, v|
        @mo['info'] << { get_data_from_edit_label.call(@mo_main_page_edit, k) => get_data_from_edit_input.call(@mo_main_page_edit, v) }
      end

      # номера в таблице строк с наименованием и числом сотрудников
      mo_personal_indexes = { 1 => 2, 4 => 5, 7 => 8, 10 => 11, 13 => 14, 16 => 17, 19 => 20, 22 => 23, 25 => 26, 28 => 29, 31 => 32 }
      # заполним количество сотрудников
      mo_personal_indexes.each do |k, v|
        @mo['employees'] << { text_from_a_in_table.call(@main_page, k, 'table:first td') => text_from_a_in_table.call(@main_page, v, "table td") }
      end

      # Есть ли у pdf МО
      @mo['pdf'] = have_pdf?(@main_page)

      i = 0
      b = 0
      buildings_links = []
      departmets_links = []
      all_computers = []
      # смотрим список зданий в МО
      while !is_over_table_on_page.call(@main_page, i)
        # получаем ссылки на все здания с главной страницы о МО
        buildings_links << href_from_a_in_table.call(@main_page, i)
        # смотрим страницу информации о здании
        building_page_edit = get_page.call(buildings_links[b] + '/edit')
        building_data = { 
          get_data_from_edit_label.call(building_page_edit, "kladr_city") => get_data_from_edit_input.call(building_page_edit, '#mbuilding_city'),
          get_data_from_edit_label.call(building_page_edit, "kladr_street") => get_data_from_edit_input.call(building_page_edit, '#mbuilding_street'),
          get_data_from_edit_label.call(building_page_edit, "kladr_building") => get_data_from_edit_input.call(building_page_edit, '#mbuilding_house'),
          get_data_from_edit_label.call(building_page_edit, "mbuilding_corpus") => get_data_from_edit_input.call(building_page_edit, '#mbuilding_corpus'),
          get_data_from_edit_label.call(building_page_edit, "mbuilding_building") => get_data_from_edit_input.call(building_page_edit, '#mbuilding_building'),
          'vipnet' => (building_page_edit.at('input [@checked=checked]').nil? ? false : true)
        }
        # 
        building_page = get_page_nokogirize.call(@main_page, buildings_links[b], i)
        building_pdf = { 'pdf' => have_pdf?(building_page) }
        department_pdf = {}
        department_index = 0
        departments = {}
        employees = {}
        department_page = ''
        # смотрим список отделений
        unless is_empty_table_on_page.call(building_page)
          while !is_over_table_on_page.call(building_page, department_index)
            departmets_links << href_from_a_in_table.call(building_page, department_index) 
            departmets_links.each do |l|
              department_page = get_page.call(l)
              department_page_edit = get_page.call(l + '/edit')
              department_pdf = { 'pdf' => have_pdf?(department_page) }
              # смотрим сколько сотрудников работают в отделении
              employees = { 
                'employees' => [
                  { 
                    get_data_from_edit_label.call(department_page_edit, "department_doctor_count") => get_data_from_edit_input.call(department_page_edit, "#department_doctor_count"),
                    get_data_from_edit_label.call(department_page_edit, "department_sr_medpersonal_count") => get_data_from_edit_input.call(department_page_edit, "#department_sr_medpersonal_count"),
                    get_data_from_edit_label.call(department_page_edit, "department_ml_medpersonal_count") => get_data_from_edit_input.call(department_page_edit, "#department_ml_medpersonal_count")
                  }
                ] 
              }
            end
            # собираем названия кабинетов, ссылки на них, и информацию о компьютерах 
            room_index = 0
            room_links = []
            room_page = ''
            rooms = {}
            computers = []
            office_appliances = {}
            med_technics = {}
            computers = []
            unless is_empty_table_on_page.call(department_page)
              while !is_over_table_on_page.call(department_page, room_index)
                room_links << href_from_a_in_table.call(department_page, room_index)
                room_links.each do |l|
                  room_page = get_page.call(l)
                end
                room_pdf = { 'pdf' => have_pdf?(room_page) }
                # смотрим есть ли сканеры, принтеры и считыватели штрих кодов
                office_appliances = { 
                  'Принтер' => element_checked_in_table.call(room_page, 'room_org_printer'),
                  'Сканер' => element_checked_in_table.call(room_page, 'room_org_scanner'),
                  'Считыватель штрих-кодов' => element_checked_in_table.call(room_page, 'room_org_codereader')
                }
                # смотрим что есть из медоборудования
                med_technics = {}
                @list_of_medtechnics.each do |name, dev|
                  dev.each do |k, v|
                    med_technics[name] = [ element_checked_in_table.call(room_page, k), element_checked_in_table.call(room_page, v) ] 
                  end
                end
                # смотрим информацию о компьютерах
                # patch
                computers = []
                computers_count = 0
                # patch 
                room_computer_index = 0
                room_page_computers = room_page.search("table:first")
                unless is_empty_table_on_page.call(room_page_computers, "tbody tr.fields td input")
                  computers_count = room_page_computers.search("tr.fields").count
                  computers = []
                  computers << { 'computers_count' => computers_count }
                  (0..(computers_count - 1)).each do |comp_index|
                    comp_fields = room_page_computers.search("tr.fields")
                    comp_serial = comp_fields.at("#room_pcs_attributes_#{comp_index}_number")['value']
                    comp_year = comp_fields.at("#room_pcs_attributes_#{comp_index}_year")['value']
                    # сбор всей информации о компьютерах
                    computers << { 
                      "#{comp_serial} / #{comp_year}" => { 
                        'Подключен к ЛВС/Интернет' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_is_connected"),
                        'МИС' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_soft_med"),
                        'Электронная регистратура' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_soft_reg"),
                        'Система архивного хранения изображений' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_soft_pacs "),
                        'Система диспетчеризации санитарного автотранспорта' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_soft_transport"),
                        'Бухгалтерия' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_soft_buh"),
                        'Кадровый учет' => element_checked_in_table.call(comp_fields, "room_pcs_attributes_#{comp_index}_soft_personal ")
                      } 
                    }
                    # добавить в список все компьютеры всех отделений и кабинетов
                    all_computers << comp_serial 
                  end
                end
                # смотрим общую информацию о помещении
                room_info =  { 
                  get_data_from_edit_label.call(room_page, "room_floor") => get_data_from_edit_input.call(room_page, '#room_floor'),
                  get_data_from_edit_label.call(room_page, "room_place_count") => get_data_from_edit_input.call(room_page, '#room_place_count'),
                  get_data_from_edit_label.call(room_page, "room_specialization") => get_data_from_edit_input.call(room_page, '#room_specialization')
                }
                rooms[text_from_a_in_table.call(department_page, room_index)] = [room_pdf, 'info' => room_info, 'office appliances' => office_appliances, 'med technics' => med_technics, 'computers' => computers ]
                room_index += 3
              end
            end
            # заполняем информацию об отделениях
            departments[text_from_a_in_table.call(building_page, department_index)] = [department_pdf, employees, rooms]
            department_index += 3
          end
        end
        # заполняем информацию о зданиях
        @mo['buildings'] << { @main_page.search("table:last td a")[i].text => [building_pdf, departments, building_data] }
        i += 3
        b += 1
        sleep 0.8
      end
      @mo['computers_count'] = all_computers.size
      @mo
    end
  end

  get '/' do
    erb :index
  end

  post "/parse" do
    @link = params[:mo]
    @data = start_parse @link
    erb :parse
  end

end
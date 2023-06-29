module Schedulable

  module ActsAsSchedulable

    extend ActiveSupport::Concern

    module ClassMethods

      def acts_as_schedulable(name, options = {})

        name||= :schedule
        # attribute = :date

        has_one name, as: :schedulable, dependent: :destroy, class_name: 'Schedule'
        accepts_nested_attributes_for name

        if options[:occurrences]

          # setup association
          if options[:occurrences].is_a?(String) || options[:occurrences].is_a?(Symbol)
            occurrences_association = options[:occurrences].to_sym
            options[:occurrences] = {}
          else
            occurrences_association = options[:occurrences][:name]
            options[:occurrences].delete(:name)
          end
          options[:occurrences][:class_name] = occurrences_association.to_s.classify
          options[:occurrences][:as]||= :schedulable
          options[:occurrences][:dependent]||:destroy
          options[:occurrences][:autosave]||= true

          has_many occurrences_association, **options[:occurrences]

          # table_name
          occurrences_table_name = occurrences_association.to_s.tableize

          # remaining
          remaining_occurrences_options = options[:occurrences].clone
          remaining_occurrences_association = ("remaining_" << occurrences_association.to_s).to_sym
          has_many remaining_occurrences_association, -> { where("#{occurrences_table_name}.date >= ?", Time.current).order('date ASC') }, **remaining_occurrences_options

          # previous
          previous_occurrences_options = options[:occurrences].clone
          previous_occurrences_association = ("previous_" << occurrences_association.to_s).to_sym
          has_many previous_occurrences_association, -> { where("#{occurrences_table_name}.date < ?", Time.current).order('date DESC')}, **previous_occurrences_options

          ActsAsSchedulable.add_occurrences_association(self, occurrences_association)

          after_save "build_#{occurrences_association}".to_sym

          # TODO These hooks and the build_ method belongs on the Schedule class.
          self.class.instance_eval do
            define_method("build_#{occurrences_association}") do
              # build occurrences for all events
              # TODO: only invalid events
              schedulables = self.all
              schedulables.each do |schedulable|
                schedulable.send("build_#{occurrences_association}")
              end
            end
          end

          define_method "build_#{occurrences_association}_after_update" do
            schedule = self.send(name)
            if schedule.changes.any?
              self.send("build_#{occurrences_association}")
            end
          end

          define_method "build_#{occurrences_association}" do
            # build occurrences for events
            schedule = self.send(name)

            if schedule.present?

              min_date = schedule.date.present? ? [schedule.date, Time.current].max : Time.current

              # TODO: Make configurable
              # occurrence_attribute = :date

              schedulable = schedule.schedulable
              terminating = schedule.rule != 'singular' && (schedule.until.present? || schedule.count.present? && schedule.count > 1)

              max_period = Schedulable.config.max_build_period || 1.year
              max_date = min_date + max_period

              max_date = terminating ? [max_date, (schedule.last.to_time rescue nil)].compact.min : max_date

              max_count = Schedulable.config.max_build_count || 100
              max_count = terminating && schedule.remaining_occurrences.any? ? [max_count, schedule.remaining_occurrences.count].min : max_count

              # Get schedule occurrence dates
              times = schedule.occurrences_between(min_date.to_time, max_date.to_time)
              times = times.first(max_count) if max_count > 0

              # build occurrences
              occurrences = schedulable.send(occurrences_association)
              times.each do |time|
                occurrences.find_by_date(time) || occurrences.create(date: time)
              end

              # Clean up unused remaining occurrences
              schedulable.send("remaining_#{occurrences_association}").where.not(date: times).destroy_all
            end
          end
        end
      end

    end

    def self.occurrences_associations_for(clazz)
      @@schedulable_occurrences||= []
      @@schedulable_occurrences.select { |item|
        item[:class] == clazz
      }.map { |item|
        item[:name]
      }
    end

    private

    def self.add_occurrences_association(clazz, name)
      @@schedulable_occurrences||= []
      @@schedulable_occurrences << {class: clazz, name: name}
    end


  end
end
ActiveRecord::Base.send :include, Schedulable::ActsAsSchedulable

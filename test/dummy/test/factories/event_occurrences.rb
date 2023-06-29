FactoryBot.define do
  factory :event_occurrence do
    date { "2015-04-08 21:12:41" }
    schedulable nil
  end

  factory :schedule do
    rule { 'weekly' }
    day { ['monday'] }
    time { Time.now + 1.hour }
    count { 10 }
    self.until { DateTime.now + 3.months }
  end

  factory :event do
    name { "My Event" }
    schedule
  end
end

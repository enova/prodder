module Prodder
  class Railtie < Rails::Railtie
    rake_tasks do
      load "prodder/prodder.rake"
    end
  end
end

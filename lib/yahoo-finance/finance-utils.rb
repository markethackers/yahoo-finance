# YahooFinance Module for YahooFinance gem
module YahooFinance
  # FinanceUtils Module
  module FinanceUtils
    def self.included(base)
      base.extend(self)
    end

    HEADERS  = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0",
      "Accept" => "application/json",
    }

    MARKETS = OpenStruct.new(
      us: OpenStruct.new(
        nasdaq: OpenStruct.new(
          url: "https://api.nasdaq.com/api/screener/stocks?tableonly=true&limit=10000&offset=0&exchange=nasdaq&download=true"),
        nyse: OpenStruct.new(
          url: "https://api.nasdaq.com/api/screener/stocks?tableonly=true&limit=10000&offset=0&exchange=nyse&download=true"),
        amex: OpenStruct.new(
          url: "https://api.nasdaq.com/api/screener/stocks?tableonly=true&limit=10000&offset=0&exchange=amex&download=true")))

    MARKET_NAMES = %w[nyse nasdaq amex]

    Company  = Struct.new(:symbol, :name, :last_sale, :market_cap, :ipo_year, :sector, :industry, :summary_quote, :market)
    Sector   = Struct.new(:name)
    Industry = Struct.new(:sector, :name)

    def map_company(row, market)
      Company.new(row["symbol"],   row["name"],
                  row["lastsale"], row["marketcap"],
                  row["ipoyear"],  row["sector"],
                  row["industry"], row["url"], market)
    end

    def companies(country, markets = MARKET_NAMES)
      return [] unless MARKETS[country]
      markets = Array(markets)
      if markets.any?
        markets.map { |market| companies_by_market(country)[market] }.flatten
      else
        companies_by_market(country).values.flatten
      end
    end

    def companies_by_market(country, markets = MARKET_NAMES)
      Array(markets).inject({}) do |h, market|
        companies = []
        next unless MARKETS[country][market]

        response = http_client.get(MARKETS[country][market].url, nil, HEADERS)

        json = JSON.parse(response.body)
        rows = json["data"]["rows"]

        if response.code != 200 || rows.blank?
          fail YahooFinance::HttpRequestError.new(response.code, reponse.body)
        end

        rows.each do |row|
          companies << map_company(row, market)
        end

        h[market] = companies
        h
      end
    end

    def sectors(country, markets = MARKET_NAMES)
      companies(country, markets).map { |c| Sector.new(c.sector) }.uniq
    end

    def industries(country, markets = MARKET_NAMES)
      companies(country, markets).map { |c| Industry.new(c.sector, c.industry) }.uniq
    end

    def symbols_by_market(country, market)
      companies = companies_by_market(country, market)

      companies.collect{|company| company.symbol}.uniq
    end
  end
end

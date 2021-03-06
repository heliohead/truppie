require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = true
  setup do
     StripeMock.start
     @stripe_helper = StripeMock.create_test_helper
  end

  teardown do
    StripeMock.stop
  end
  
  test "getting the status of a order" do
    assert true
  end
  
  test "one tour created" do
    assert_equal 4, Order.count
  end
  
  test "update a payment fee and liquid value into redis" do
    skip("migrate to stripe")
    body_for_order = {
      :status => "succeeded",
      :amount => {
        :fees => 10,    
        :liquid => 20,
        :total => 30 
      }
    }
    
    FakeWeb.register_uri(:get, %r|sandbox.moip.com.br/v2/payments/PAY-32LJ77AT4JNN|, :body => body_for_order.to_json, :status => ["200", "Success"])
    
    order = orders(:one)
    fee = order.update_fee
    
    assert_equal fee, {"fee"=>10, "status"=>"AUTHORIZED", "liquid"=>20, "total"=>30}
  end
  
  test "get a payment fee and liquid value updated" do
    skip("migrate to stripe")
    body_for_order = {
      :status => "AUTHORIZED",
      :amount => {
        :fees => 10,    
        :liquid => 20,
        :total => 30 
      }
    }
    FakeWeb.register_uri(:get, %r|sandbox.moip.com.br/v2/payments/PAY-32LJ77AT4JNN|, :body => body_for_order.to_json, :status => ["200", "Success"])
    order = orders(:one)
    order.update_fee
    fee = order.fees
    
    assert_equal fee, {"fee"=>10, "status"=>"AUTHORIZED", "liquid"=>20, "total"=>30}
    assert_equal order.total_fee, 10
    assert_equal order.amount_total, 30
    assert_equal order.price_with_fee, 20
    
    assert_equal order.available_liquid, 0
    assert_equal order.available_total, 0
    assert_equal order.available_with_taxes, 0
  end
  
  test "get a real payment and get the tax" do
    skip("real payment call")
    auth = Moip2::Auth::Basic.new(Rails.application.secrets[:moip_token], Rails.application.secrets[:moip_key])
     client = Moip2::Client.new(:sandbox, auth)
     api = Moip2::Api.new(client)
     order = api.order.create(
          {
              own_id: "ruby_sdk_1",
              items: [
                {
                  product: "Nome do produto",
                  quantity: 1,
                  detail: "Mais info...",
                  price: 1000
                }
              ],
              customer: {
                own_id: "ruby_sdk_customer_1",
                fullname: "Jose da Silva",
                email: "sandbox_v2_1401147277@email.com",
              }
          }
      )
     payment = api.payment.create(order.id,
          {
              installment_count: 1,
              funding_instrument: {
                  method: "CREDIT_CARD",
                  credit_card: {
                      expiration_month: 04,
                      expiration_year: 18,
                      number: "4012001038443335",
                      cvc: "123",
                      holder: {
                          fullname: "Jose Portador da Silva",
                          birthdate: "1988-10-10",
                          tax_document: {
                              type: "CPF",
                              number: "22222222222"
                      },
                          phone: {
                              country_code: "55",
                              area_code: "11",
                              number: "55667788"
                          }
                      }
                  }
              }
          }
      )
      #puts payment.inspect
      order = Order.create(
        :status => 'PAYMENT.AUTHORIZED',
        :price => 1000,
        :status_history => ['PAYMENT.WAITING','PAYMENT.AUTHORIZED'],
        :final_price => 1000,
        :payment => payment[:id],
        :user => User.last,
        :tour => Tour.last
      )
      puts payment.inspect
      assert_equal payment[:events][1][:type], "PAYMENT.CREATED"
      assert_equal payment[:amount][:fees], 0
      assert_equal payment[:fees][0].to_h, {:type=>"TRANSACTION", :amount=>0}
      fees = order.fees
      assert_equal fees, {:fee=>0, :liquid=>0, :total=>0}
      assert_equal order.settled, {:fee=>0, :liquid=>0, :total=>0}
  end
end

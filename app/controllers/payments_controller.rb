class PaymentsController < ApplicationController
  def client_token
    render json: { client_token: Braintree::ClientToken.generate }
  end

  def purchase
    id = params[:id]
    if id == 'flakycookie'
      amount_cents = params[:amount_cents].to_i
      if amount_cents
        begin
          customer = Stripe::Customer.create(
            :email => payment_params[:email],
            :card  => params[:stripeToken],
            :metadata => {
              :first_name => params[:first_name],
              :last_name => params[:last_name],
              :source => 'cordon',
            },
          )
          amount = (amount_cents * 1.017).ceil + 20
          charge = Stripe::Charge.create(
            :customer    => customer.id,
            :amount      => amount,
            :currency    => 'gbp',
            :metadata    => {
              :source => 'cordon'
            }
          )
          render json: { status: "success" }
          return
        rescue Stripe::CardError => e
          render json: { errors: e.message }, status: 400
        end
      end
    end

    @item = Item.find(params[:id])

    if @item.capacity != 0 and (@item.payments_count > @item.capacity)
      render json: { errors: { "item": "is sold out" } }, status: 400 and return
    end

    customer = Stripe::Customer.create(
      :email => payment_params[:email],
      :card  => params[:stripeToken]
    )

    amount = (@item.price_cents * 1.017).ceil + 20

    charge = Stripe::Charge.create(
      :customer    => customer.id,
      :amount      => amount,
      :description => "#{@item.name}, from society #{@item.society.name}",
      :currency    => 'gbp'
    )

    @payment = @item.payments.build(payment_params)

    @payment.save!
    @item.society.balance += @item.price
    @item.society.save!
    render json: { data: { payment: @payment } }

    rescue Stripe::CardError => e
      render json: { errors: e.message }, status: 400
  end

  private

  def payment_params
    params.require(:payment).permit(:email)
  end
end

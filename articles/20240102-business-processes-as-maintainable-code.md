Business Processes as Maintainable Code
business-processes-as-maintainable-code
programming

This article is going to walk through structuring web applications (yes, even large ones) as maintainable, modular code paths that maintain a clear separation of storage, process, and server.  The article will be written in python and will be translated to some other languages at the end.

First, let's take a look at a typical order endpoint (pseudo-ish, we're not going to run this or curl, just analyze the structure):

```python
from flask import Flask, request, session
from peewee import Model, SqliteDatabase

app = Flask('example')
db = SqliteDatabase('local.db')

app.secret_key = 'abc'


class Order(Model):
    class Meta:
        database = db

    id = BigAutoField('id')
    user_id = BigIntegerField('user_id')

class LineItem(Model):
    class Meta:
        database = db

    id = BigAutoField('id')
    order_id = BigIntegerField('order_id')
    quantity = IntegerField('quantity')
    product_id = IntegerField('product_id')

class Product(Model):
    class Meta:
        database = db

    id = BigAutoField('id')
    name = StringField('name')
    cost = IntegerField('cost')
    price = IntegerField('price')

@app.route('/order', methods=['POST'])
def order():
    details = request.get_json()

    order = Order(user_id=session['user_id'])
    order.save()
    line_items = []
    product_map = {
        k.id: k
        for k in Product.select().where(Product.id.in_(details['products']))
    }

    for product_id, quantity in details['products'].items():
        if not product_map.get(product_id):
            return f'error: product_id({product_id}) does not exist'
        if quantity <= 0:
            return f'error: product {product_map[product_id].name} quantity must be > 0'

        amount += product_map[product].price
        LineItem(
            order=order,
            quantity=quantity,
            product_id=product_id,
        ).save()


    return 'success'
```

Typically this stuff is littered over a number of files and you'd do all of this in a transaction, etc etc.
Right now we're making an example of how a typical endpoint is written so we can pull it apart and find useful
indirections within it that will minimize the sprawl and mess that exists in a lot of codebases.

So, we're going to look specifically at the `def order()`.  It's responsibilities are nearly endless, and again,
this is a pretty typical endpoint.  This endpoint does:

1. Parse out the details of the request
2. Validates inputs 
3. Handles the process of order creation
4. Return a valid response or renders a template

This is too many responsibilities.  How often is the "break up code into logical chunks" horse beaten?  A whole lot.
You might be thinking, it's fine! The ORM does the DB, the endpoint does the process! Sure. In this readable
small example it's probably fine until another endpoint, or, one of your colleagues creates a script needs to create an order and
then you have to hack around because the *process* is muddled with business logic, ORM magic, HTTP server magic,
and templating.

Well, smarty pants, how should these be broken up rather than the typical way we see?

Break the process apart from the rest of the noise.  To start, we'll take a look at what that looks like in isolation:

```python
class ICreateOrder:
    def __init__(self, user_id: int, order_details: dict):
        # do some validations
        ## products and quantities all exist:
        product_map = {
            k.id: k
            for k in Product.select().where(Product.id.in_(details['products']))
        }
        self.product_map = product_map
        self.line_items = []
        for product_id, quantity in details['products'].items():
            if not product_map.get(product_id):
                raise Exception(f'error: product_id({product_id}) does not exist')
            if quantity <= 0:
                raise Exception(f'error: product {product_map[product_id].name} quantity must be > 0')

            # may as well do this while we're in here
            self.line_items.append(
                LineItem(
                    quantity=quantity,
                    product_id=product_id,
                )
            )

        ## ensure user exists
        User.get(User.id == user_id)

        ## all we need.
        self.user_id = user_id
        self.order_details = order_details            

def create_order(order_details: ICreateOrder):
    order = Order(user_id=order_details.user_id)
    order.save()
    for li in order_details.line_items:
        li.order_id = order.id
    LineItem.insert_many(order_details.line_items)
```

Sure, the code is longer but now you can see a clear deliniation of responsibility.
`ICreateOrder` is an interface responsible for validating inputs, `create_order` is very clear on
what actions it takes and when it does those actions.  It creates an order, it updates all of the line
items we cleverly stored (so as not to iterate the list twice) with the correct order id, and then saves
them.

Now our http endpoint can look like this:

```python
@app.route('/order', methods=['POST'])
def order():
    details = request.get_json()
    create_order(ICreateOrder(details))
```

More clarity. Someone pinch me. We can still improve upon this but now we see the responsibilities better:

HTTP endpoint:

- Parse out the details of the request
- Return a valid response or renders a template

`ICreateOrder`:

- Creates/Saves ORM objects

`create_order`:

- Handles the process of order creation

Clarity is great but what do we really gain? We gain the ability to re-use this process elsewhere. Once this
function is hooked up to another system or used via an API while you migrate to react you can *just use* the
process without mucking around in the other thousand endpoints, or rewriting the function as a rest call or...

You said we can improve upon this still!? HEKCIN YES [sic]. The fact that you need to screw around with any of this
is crazy making enough but we're seeing clear business processes developing independent of the noise, let's make
some more indirection with interfaces.

```python
class ResponseType(Enum):
    JSON=1
    TEMPLATE=2

class CustomResponse:
    def render(self, response_type: ResponseType = ResponseType.JSON):
        data = ''
        mime_type = ''
        if response_type == ResponseType.TEMPLATE:
            data = self.render_template()
            mime_type = 'text_html'
        else:
            data = json.dumps(self.data)

        return Response(
            response=data,
            status=self.status,
            mimetype=mime_type
        )

    def render_template(self):
        # plug in your template renderer here
        return template_engine.render(self.template_file, self.data)

class CreateOrderResponse(CustomResponse):
    template_file = 'templates/create_order_response.templ'

    def __init__(self, data, status: int = 201):
        self.status = status
        self.data = data
```

A lot of code here that kind of looks like overkill, we're just returning an HTTP response afterall. Yea, you're right,
kind of.  This logic gets repeated across endpoints constantly and they never remain consistent long term.
Instead, we can centralize this with an explicit way of handling responses that actually assists and simplifies debugging
problems and working/reasoning your way through the HTTP request -> process(es) -> response flow.

```python
def create_order(order_details: ICreateOrder) -> CustomResponse:
    order = Order(user_id=order_details.user_id)
    order.save()
    amount = 0
    for li in order_details.line_items:
        li.order_id = order.id
        amount += li.quantity * self.product_map[li.product_id].price

    LineItem.insert_many(order_details.line_items)

    return CreateOrderResponse(
        data={
            'amount': amount,
            'order_id': order.id,
        }
    )
```

We've added some useful details our consumers may want in the future; amount, and order\_id.
This response interface allows our endpoint to make the distinction on how it renders the return
values and what it actually does with that information.  It's important to note that you definitely
*should not* call `.render()` in the process function, you don't know who or what is consuming this! For instance,
if we have a business process that needs to create an order in the middle of another process they can still use
`CreateOrderResponse.data` to grab the amount/order\_id.  Also notice, we don't have any HTTP
server functions muddled in here, there's no ORM trouble mixed into it - we're already using the
ORM as a data structure _as one should!_

Likewise our endpoint needs to change now:

```python
@app.route('/order', methods=['POST'])
def order():
    details = request.get_json()
    return create_order(ICreateOrder(details)).render()
```

That's it.  That's about as complicated as an endpoint should ever be. From here we could introduce
a decorators that takes an `I` interface to validate the incoming data to ensure it's well formed
before we even get to the endpoint.  We'll ignore this since decorators aren't well understood even
by pythonistas.

In this case you couldd end up with an endpoint that looks like:

```python
@endpoint('/order', methods=['POST'], ICreateOrder)
def order(in: ICreateOrder):
    return create_order(in)
```

And the decorator would handle calling `.render`, creating the `ICreateOrder` from the request JSON,
and whatever else our little heart desires.  Maybe setting up a transaction for the process, maybe
ejecting the CD-ROM so we have somewhere to place our coffee mug.

This is a really nice way to handle errors since the decorator can handle the errors appropriately.
Here's what that would look like with error handling in the endpoint itself:

```python
class GenericException(CustomResponse):
    def __init__(self, data, status=400):
        self.data = {
            'message': str(data),
            'backtrace': traceback.format_exception(
                etype=type(data),
                value=data,
                tb=data.__traceback__,
            ),
        }
        self.status = status

@app.route('/order', methods=['POST'])
def order():
    details = request.get_json()
    try:
        return create_order(ICreateOrder(details)).render()
    except Exception as e:
        return GenericException(data=e).render()
```

Now when our endpoint raises an exception we'll get back reasonable data.

That's it.  That's all there is to it.  This is a very targeted/specific example of how to move all of your
endpoint code into logical chunks that make sense across the HTTP server, database layers and abstractions,
template/json endpoint rendering, and provides a way for your process functions to model the actual business
process they're performing rather than modeling how a typical HTTP request flows. It's a small change, requires
more code, but you gain so much in readability and logical separation of responsibilities that you have practically
no excuse *not* to reuse the process where needed!

## Examples ported to other languages

These are all going to be fragments rather than reproducing the entirety of the examples above as even if you're
not a python person (I'm not, either) it's readable enough to follow along.

### Go

```go

// types
type I_CreateOrder struct {
    Items []struct{
        ProductID uint64 `json:"product_id"`
        Quantity  uint64 `json:"quantity"`
    }
}

func (i *I_CreateOrder) FromJSON(json []byte) *Response {
    if err := json.Unmarshal(json, i); err != nil {
        return S_Exception{
            Message: "Invalid input.",
            Error: err.Error(),
        }
    }
    return nil
}

type Response interface {
    func Render() (int, string)
}

type S_CreateOrder struct {
    OrderID uint64 `json:"order_id"`
    Amount  uint64 `json:"amount"`
}
func (co *S_CreateOrder) Render() (int, string) {
    //...this logic can be extracted out
}

type S_Exception struct {
    Message string
    Error   string
}
func (e *S_Exception) Render() (int, string) {
    //...same
}

// Create order process
func CreateOrder(db *gorm.DB, details *I_CreateOrder) *Response {
    pids := []uint64{}
    for _, detail := range details.Items {
        if detail.Quantity <= 0 {
            return S_Exception{
                Message: "Quantity of order item must be > 0",
                Error: "",
            }
        }
        pids = append(pids, detail.ProductID)
    }
    ps := []Product{}
    if err := db.Where("id in (?)", pids).Find(&ps).Error; err != nil {
        return S_Exception{
            Message: "Requested product id doesn't exist",
            Error: err.Error(),
        };
    }
    
    // do all of your ORM stuff

    return S_CreateOrder{
        OrderID: order.ID,
        Amount: order.Amount,
    }
}



```

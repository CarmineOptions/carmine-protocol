

func convert_price{range_check_ptr}(price : felt, m : felt) -> (price : felt):
    alloc_locals

    let (is_convertable) = is_le(price, Math64x61_INT_PART)
    if is_convertable == TRUE:
        assert_le(price, Math64x61_INT_PART)
        let (converted_price) = Math64x61_fromFelt(price)
        return (converted_price)
    end

    let m_1 = m / 2
    let m_2 = m - m_1

    let c = price / m_1
    let (a) = convert_price(c, m_1)

    let b_tmp = price / m_1
    let b_tmp2 = price - b_tmp
    let (b) = convert_price(b_tmp2, m)

    let res = a + b

    return (res)
end

func sth